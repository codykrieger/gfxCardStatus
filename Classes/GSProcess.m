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

static const CFStringRef kProcTaskKey = (const CFStringRef)__builtin___CFStringMakeConstantString("task-list");

static struct kinfo_proc *_procInfo = NULL;
static size_t _procSize = 0;
static size_t _procNum = 0;

#pragma mark - Static C methods

static void _procTask(const void *value, void *param) {
    NSMutableArray *arr = (__bridge NSMutableArray *)param;
    NSNumber *key = NULL;
    NSString *procName = NULL;
    
    int mib[3] = { CTL_KERN, KERN_ARGMAX, 0 };
    struct kinfo_proc *k = NULL;
    size_t i, sz;
    long long pid;
    char *buf, *sp, *cp;
    
    // return if we don't have any processes, or our current process pid is rubbish
    if (_procInfo == NULL)
        return;
    if (!CFNumberGetValue(value, kCFNumberLongLongType, &pid))
        return;
    
    // loop through the kernel process list, find the one that matches our current 
    // pid (must conform to AppleGraphicsControl), then break
    for (i = 0; i < _procNum; i++) {
        if (_procInfo[i].kp_proc.p_pid == pid) {
            k = &_procInfo[i];
            break;
        }
    }
    // return if we haven't found a matching service in the kernel task list
    if (k == NULL) return;
    
    key = [[NSNumber alloc] initWithLongLong:pid];
    
    sz = sizeof(i);
    if (sysctl(mib, 2, &i, &sz, NULL, 0) == -1)
        goto err;
    
    // create a buffer for reading in the process name
    buf = (char *)malloc(i);
    if (buf == NULL)
        goto err;
    
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
                    [key stringValue], kTaskItemPID, nil]];
done:
    return;
}

// update the current list of kernel tasks
static void _procUpdate() {
    // we want all process entries from the kernel
    int mib[3] = { CTL_KERN, KERN_PROC, KERN_PROC_ALL };
    
    struct kinfo_proc *info = NULL;
    size_t sz;
    
    // return if unsuccessful
    if (sysctl(mib, 3, NULL, &sz, NULL, 0) < 0)
        return;
    
    // if procInfo has stale data, reallocate it in preparation for new task list
    if (_procInfo == NULL || sz != _procSize) {
        info = realloc(_procInfo, sz);
        if (info == NULL) return;
        _procInfo = info; _procSize = sz;
    }
    
    // read tasks into procInfo and return if unsuccessful
    if (sysctl(mib, 3, _procInfo, &sz, NULL, 0) < 0)
        return;
    
    // update number of processes in the list
    _procNum = sz / sizeof(struct kinfo_proc);
}

static void _procScan(io_registry_entry_t service, NSMutableArray *arr) {
    io_registry_entry_t    child    = 0;
    io_iterator_t          children = 0;
    CFMutableDictionaryRef props    = NULL;
    
    // get all tasks that conform to AppleGraphicsControl service
    if (IOObjectConformsTo(service, "AppleGraphicsControl")) {
        kern_return_t status = IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, kNilOptions);
        
        if (status == KERN_SUCCESS && CFGetTypeID(props) == CFDictionaryGetTypeID()) {
            CFTypeRef array = CFDictionaryGetValue(props, kProcTaskKey);
            CFRange range = { 0, CFArrayGetCount(array) };
            CFArrayApplyFunction(array, range, _procTask, (__bridge void *)arr);
            CFRelease(props);
        }
    }
    
    if (IORegistryEntryGetChildIterator(service, kIOPowerPlane, &children) == KERN_SUCCESS) { // kIOServicePlane
        while ((child = IOIteratorNext(children))) {
            _procScan(child, arr);
            IOObjectRelease(child);
        }
        
        IOObjectRelease(children);
    }
}

@implementation GSProcess

#pragma mark - GSProcess API

+ (NSArray *)getTaskList {
    NSMutableArray *list = [NSMutableArray array];
    
    // find out if an external monitor is forcing the discrete gpu on
    CGDirectDisplayID displays[8];
    CGDisplayCount displayCount = 0;
    if (CGGetOnlineDisplayList(8, displays, &displayCount) == noErr) {
        for (int i = 0; i < displayCount; i++) {
            if ( ! CGDisplayIsBuiltin(displays[i]))
                [list addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                                 Str(@"External Display"), kTaskItemName,
                                 @"", kTaskItemPID, nil]];
        }
    }
    
    // scan the kernel process list for discrete gpu-using tasks
    io_registry_entry_t service = 0;
    service = IORegistryGetRootEntry(kIOMasterPortDefault);
    if (!service)
        return [NSArray array];
    
    _procUpdate();
    _procScan(service, list);
    
    IOObjectRelease(service);
    
    return list;
}

@end
