//
//  GSProcess.m
//  gfxCardStatus
//
//  Created by Cody Krieger on 6/21/11.
//  Copyright 2011 Cody Krieger. All rights reserved.
//
//  Original task list functionality Copyright 2010 Thierry Coppey.
//  (look back in repo history at proc.h/m)
//

#import "GSProcess.h"

#include <CoreFoundation/CoreFoundation.h>
#include <IOKit/IOKitLib.h>
#include <sys/sysctl.h>
#include <unistd.h>

static const CFStringRef procTaskKey = (const CFStringRef)__builtin___CFStringMakeConstantString("task-list");

static struct kinfo_proc *procInfo = NULL;
static size_t procSize = 0;
static size_t procNum = 0;

@implementation GSProcess

#pragma mark -
#pragma mark Power source helpers

// helper to get preference key from PowerSource enum
+ (NSString *)keyForPowerSource:(PowerSource)powerSource {
    return ((powerSource == psBattery) ? kGPUSettingBattery : kGPUSettingACAdaptor);
}

// helper to return current mode
//+ (SwitcherMode)switcherGetMode {
//    if ([GSMux isUsingDynamicSwitching]) return modeDynamicSwitching;
//    NSDictionary *profile = [GSProcess getGraphicsProfile];
//    return ([(NSNumber *)[profile objectForKey:@"usingIntegrated"] boolValue] ? modeForceIntegrated : modeForceDiscrete);
//}

#pragma mark -
#pragma mark Task list magic

//+ (BOOL)procInit {
//    return IOMasterPort(bootstrap_port, &procPort) == KERN_SUCCESS;
//}

//+ (void)procFree {
//    free(procInfo);
//    procInfo = NULL;
//}

static void procTask(const void *value, void *param) {
    NSMutableArray *arr = (__bridge NSMutableArray *)param;
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
    procName = [[NSString alloc] initWithUTF8String:cp];
    [arr addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                     procName, kTaskItemName,
                     [key stringValue], kTaskItemPID, nil]];
    
    free(buf);
    goto done;
err:
    [arr addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                    [[NSString alloc] initWithUTF8String:k->kp_proc.p_comm], kTaskItemName,
                    @"", kTaskItemPID, nil]];
done:
    return;
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
            CFArrayApplyFunction(array, range, procTask, (__bridge void *)arr);
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
    NSMutableArray *list = [NSMutableArray array];
    
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
    service = IORegistryGetRootEntry(kIOMasterPortDefault);
    if (!service) return [NSArray array];
    
    procUpdate();
    procScan(service, list);
    
    IOObjectRelease(service);
    
    return list;
}

@end
