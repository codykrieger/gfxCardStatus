//
//  SystemInfo.m
//  gfxCardStatus
//
//  Created by Cody Krieger on 6/21/11.
//  Copyright 2011 Cody Krieger. All rights reserved.
//
//  Original task list functionality Copyright 2010 Thierry Coppey.
//  (look back in repo history at proc.h/m)
//

#import "SystemInfo.h"

#include <CoreFoundation/CoreFoundation.h>
#include <IOKit/IOKitLib.h>
#include <sys/sysctl.h>
#include <unistd.h>

static const CFStringRef procTaskKey = (const CFStringRef)__builtin___CFStringMakeConstantString("task-list");

static mach_port_t procPort = 0;
static struct kinfo_proc *procInfo = NULL;
static size_t procSize = 0;
static size_t procNum = 0;

@implementation SystemInfo

#pragma mark -
#pragma mark Power source helpers

// helper to get preference key from PowerSource enum
+ (NSString *)keyForPowerSource:(PowerSource)powerSource {
    return ((powerSource == psBattery) ? kGPUSettingBattery : kGPUSettingACAdaptor);
}

// helper to return current mode
+ (SwitcherMode)switcherGetMode {
    if ([MuxMagic isUsingDynamicSwitching]) return modeDynamicSwitching;
    NSDictionary *profile = [SystemInfo getGraphicsProfile];
    return ([(NSNumber *)[profile objectForKey:@"usingIntegrated"] boolValue] ? modeForceIntegrated : modeForceDiscrete);
}

#pragma mark -
#pragma mark Task list magic

+ (BOOL)procInit {
    return IOMasterPort(bootstrap_port, &procPort) == KERN_SUCCESS;
}

+ (void)procFree {
    free(procInfo);
    procInfo = NULL;
}

static void procTask(const void *value, void *param) {
    NSMutableArray *arr = (NSMutableArray *)param;
    NSNumber *key = NULL;
    NSString *procName = NULL;
    
    int mib[3] = { CTL_KERN, KERN_ARGMAX, 0 };
    struct kinfo_proc *k = NULL;
    size_t i, sz;
    long long pid;
    char *buf, *sp, *cp;
    
    // return if we don't have any processes, or our current process pid is rubbish
    if (procInfo == NULL) return;
    if (!CFNumberGetValue(value, kCFNumberLongLongType, &pid)) return;
    
    // loop through the kernel process list, find the one that matches our current 
    // pid (must conform to AppleGraphicsControl), then break
    for (i = 0; i < procNum; i++) {
        if (procInfo[i].kp_proc.p_pid == pid) {
            k = &procInfo[i];
            break;
        }
    }
    // return if we haven't found a matching service in the kernel task list
    if (k == NULL) return;
    
    key = [[NSNumber alloc] initWithLongLong:pid];
    
    sz = sizeof(i);
    if (sysctl(mib, 2, &i, &sz, NULL, 0) == -1) goto err;
    
    // create a buffer for reading in the process name
    buf = (char *)malloc(i);
    if (buf == NULL) goto err;
    
    mib[1] = KERN_PROCARGS2;
    mib[2] = k->kp_proc.p_pid;
    
    sz = (size_t)i;
    if (sysctl(mib, 3, buf, &sz, NULL, 0) == -1) {
        free(buf);
        goto err;
    }
    
    // buffer buffer buffer
    cp = buf + sizeof(int);
    if ((sp = strrchr(cp, '/'))) cp = sp + 1;
    
    // we finally have the proc name!
    procName = [[[NSString alloc] initWithUTF8String:cp] autorelease];
    [arr addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                     procName, kTaskItemName,
                     [key stringValue], kTaskItemPID, nil]];
    
    free(buf);
    goto done;
err:
    [arr addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                    [[[NSString alloc] initWithUTF8String:k->kp_proc.p_comm] autorelease], kTaskItemName,
                    @"", kTaskItemPID, nil]];
done:
    [key release];
}

// update the current list of kernel tasks
static void procUpdate() {
    // we want all process entries from the kernel
    int mib[3] = { CTL_KERN, KERN_PROC, KERN_PROC_ALL };
    
    struct kinfo_proc *info = NULL;
    size_t sz;
    
    // return if unsuccessful
    if (sysctl(mib, 3, NULL, &sz, NULL, 0) < 0) return;
    
    // if procInfo has stale data, reallocate it in preparation for new task list
    if (procInfo == NULL || sz != procSize) {
        info = realloc(procInfo, sz);
        if (info == NULL) return;
        procInfo = info; procSize = sz;
    }
    
    // read tasks into procInfo and return if unsuccessful
    if (sysctl(mib, 3, procInfo, &sz, NULL, 0) < 0) return;
    
    // update number of processes in the list
    procNum = sz / sizeof(struct kinfo_proc);
}

static void procScan(io_registry_entry_t service, NSMutableArray *arr) {
    io_registry_entry_t    child    = 0;
    io_iterator_t          children = 0;
    CFMutableDictionaryRef props    = NULL;
    
    // get all tasks that conform to AppleGraphicsControl service
    if (IOObjectConformsTo(service, "AppleGraphicsControl")) {
        kern_return_t status = IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, kNilOptions);
        if (status == KERN_SUCCESS && CFGetTypeID(props) == CFDictionaryGetTypeID()) {
            CFTypeRef array = CFDictionaryGetValue(props, procTaskKey);
            CFRange range = { 0, CFArrayGetCount(array) };
            CFArrayApplyFunction(array, range, procTask, arr);
            CFRelease(props);
        }
    }
    
    if (IORegistryEntryGetChildIterator(service, kIOPowerPlane, &children) == KERN_SUCCESS) { // kIOServicePlane
        while ((child = IOIteratorNext(children))) {
            procScan(child, arr);
            IOObjectRelease(child);
        }
        IOObjectRelease(children);
    }
}

+ (NSArray *)getTaskList {
    NSMutableArray *list = [[[NSMutableArray alloc] init] autorelease];
    
    // find out if an external monitor is forcing the discrete gpu on
    CGDirectDisplayID displays[8];
    CGDisplayCount displayCount = 0;
    if (CGGetOnlineDisplayList(8, displays, &displayCount) == noErr) {
        for (int i = 0; i < displayCount; i++) {
            if ( ! CGDisplayIsBuiltin(displays[i])) {
                [list addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                                 Str(@"External Display"), kTaskItemName,
                                 @"", kTaskItemPID, nil]];
            }
        }
    }
    
    // scan the kernel process list for discrete gpu-using tasks
    io_registry_entry_t service = 0;
    service = IORegistryGetRootEntry(procPort);
    if (!service) return [NSArray array];
    
    procUpdate();
    procScan(service, list);
    
    IOObjectRelease(service);
    
    return list;
}

#pragma mark -
#pragma mark Machine profile magic

+ (NSDictionary *)getGraphicsProfile {
    NSMutableDictionary *profile = [NSMutableDictionary dictionary];
    
    // call system_profiler SPDisplaysDataType in order to get GPU profile
    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath:@"/usr/sbin/system_profiler"];
    [task setArguments:[NSArray arrayWithObject:@"SPDisplaysDataType"]];
    
    NSPipe *pipe = [NSPipe pipe];
    [task setStandardOutput:pipe];
    
    [task launch];
    NSData *data = [[pipe fileHandleForReading] readDataToEndOfFile];
    [task waitUntilExit];
    [task release];
    
    // split up the output into lines
    NSString *output = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSArray *lines = [output componentsSeparatedByString:@"\n"];
    [output release];
    
    // parse the output into a dictionary of dictionaries based on section names,
    // which are determined by whitespace indentation level
    NSMutableDictionary *profilerInfo = [[NSMutableDictionary alloc] init];
    NSMutableArray *currentKeys = [[NSMutableArray alloc] init];
    int currentLevel = 0;
    
    for (NSString *obj in lines) {
        int lengthBeforeTrim = [obj length];
        int whitespaceLength = 0;
        obj = [obj stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        whitespaceLength = lengthBeforeTrim - [obj length];
        
        if ([obj isEqualToString:@""]) continue;
        if (whitespaceLength < 2) currentLevel = 0;
        else currentLevel = (whitespaceLength / 2) - 1;
        
        while ([currentKeys count] > currentLevel) {
            [currentKeys removeLastObject];
        }
        
        if ([obj hasSuffix:@":"]) {
            obj = [obj stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@":"]];
            
            if ([currentKeys count] == 0) {
                [profilerInfo setObject:[[[NSMutableDictionary alloc] init] autorelease] forKey: obj];
                [currentKeys addObject:obj];
            } else {
                NSMutableDictionary *tempDict = profilerInfo;
                for (int i = 0; i < [currentKeys count]; i++) {
                    tempDict = [tempDict objectForKey:[currentKeys objectAtIndex:i]];
                }
                
                [tempDict setObject:[[[NSMutableDictionary alloc] init] autorelease] forKey:obj];
                [currentKeys addObject:obj];
            }
            
            continue;
        } else {
            NSArray *tempArray = [obj componentsSeparatedByString:@": "];
            NSMutableDictionary *tempDict = profilerInfo; // = [dict objectForKey:currentKey];
            
            for (int i = 0; i < [currentKeys count]; i++) {
                tempDict = [tempDict objectForKey:[currentKeys objectAtIndex:i]];
            }
            
            [tempDict setObject:[NSString stringWithFormat:@"%@", [tempArray objectAtIndex:1]] forKey:[tempArray objectAtIndex:0]];
        }
    }
    
    // begin figuring out which machine we're using by attempting to get dictionaries
    // based on the integrated chipset names
    NSDictionary *graphics = (NSDictionary *)[profilerInfo objectForKey:@"Graphics/Displays"];
    NSDictionary *integrated = (NSDictionary *)[graphics objectForKey:@"Intel HD Graphics"];
    if (!integrated) integrated = (NSDictionary *)[graphics objectForKey:@"Intel HD Graphics 3000"];
    
    if (!integrated) {
        [profile setObject:[NSNumber numberWithBool:YES] forKey:@"legacy"];
        integrated = (NSDictionary *)[graphics objectForKey:@"NVIDIA GeForce 9400M"];
        
        if (!integrated) {
            // display a message - must be using an unsupported model
            NSLog(@"*** UNSUPPORTED SYSTEM BEING USED ***");
            [profile setObject:[NSNumber numberWithBool:YES] forKey:@"unsupported"];
        } else {
            [profile setObject:[NSNumber numberWithBool:NO] forKey:@"unsupported"];
        }
    } else {
        [profile setObject:[NSNumber numberWithBool:NO] forKey:@"legacy"];
        [profile setObject:[NSNumber numberWithBool:NO] forKey:@"unsupported"];
    }
    
    // figure out whether or not we're using the integrated GPU
    NSDictionary *integratedDisplays = (NSDictionary *)[integrated objectForKey:@"Displays"];
    BOOL usingIntegrated = NO;
    
    for (NSString *key in [integratedDisplays allKeys]) {
        NSDictionary *tempDict = (NSDictionary *)[integratedDisplays objectForKey:key];
        
        for (NSString *otherKey in [tempDict allKeys]) {
            usingIntegrated = !([(NSString *)[tempDict objectForKey:otherKey] isEqualToString:@"No Display Connected"]);
            break;
        }
        if (usingIntegrated) break;
    }
    
    // if we're using an unsupported machine config, set profile values to empty strings just in case
    // otherwise, set the integrated and discrete GPU names in the profile, as well as whether or not
    // we're using the integrated GPU
    if ([[profile objectForKey:@"unsupported"] boolValue]) {
        [profile setObject:@"" forKey:@"integratedString"];
        [profile setObject:@"" forKey:@"discreteString"];
        [profile setObject:@"" forKey:@"usingIntegrated"];
    } else {
        NSEnumerator *keys = [graphics keyEnumerator];
        NSString *key;
        while ((key = (NSString *)[keys nextObject])) {
            if ([[key stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] isEqualToString:@""]) continue;
            
            if ([key isEqualToString:@"Intel HD Graphics"] || 
                [key isEqualToString:@"Intel HD Graphics 3000"] || 
                [key isEqualToString:@"NVIDIA GeForce 9400M"]) {
                [profile setObject:key forKey:@"integratedString"];
            } else {
                [profile setObject:key forKey:@"discreteString"];
            }
        }
        
        [profile setObject:[NSNumber numberWithBool:usingIntegrated] forKey:@"usingIntegrated"];
    }
    
    [profilerInfo release];
    [currentKeys release];
    
    return profile;
}

@end
