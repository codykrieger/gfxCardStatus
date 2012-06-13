//
//  GSPower.m
//  gfxCardStatus
//
//  Created by Cody Krieger on 6/12/12.
//  Copyright (c) 2012 Cody Krieger. All rights reserved.
//

#include <IOKit/IOKitLib.h>
#include <IOKit/ps/IOPSKeys.h>
#include <IOKit/ps/IOPowerSources.h>
#import "GSPower.h"

static void powerSourceChanged(void *context);
static void registerPowerSourceNotification(GSPower *powerSourceMonitor);

static BOOL stringsAreEqual(CFStringRef a, CFStringRef b) {
    if (a == nil || b == nil) {
        return NO;
    }
    
    return (CFStringCompare(a, b, 0) == kCFCompareEqualTo);
}

static GSPowerType getCurrentPowerSource() {
    GSPowerType status = GSPowerTypeUnknown;
    
    CFTypeRef blob = IOPSCopyPowerSourcesInfo();
    CFArrayRef list = IOPSCopyPowerSourcesList(blob);
    
    int count = CFArrayGetCount(list);
    
    if (count == 0) {
        status = GSPowerTypeAC;
        goto cleanup;
    }
    
    for (int i = 0; i < count; i++) {
        CFTypeRef source;
        CFDictionaryRef description;
        
        source = CFArrayGetValueAtIndex(list, i);
        description = IOPSGetPowerSourceDescription(blob, source);
        
        if (stringsAreEqual(CFDictionaryGetValue(description, CFSTR(kIOPSTransportTypeKey)), CFSTR(kIOPSInternalType))) {
            CFStringRef currentState = CFDictionaryGetValue(description, CFSTR(kIOPSPowerSourceStateKey));
            
            if (stringsAreEqual(currentState, CFSTR(kIOPSACPowerValue))) {
                status = GSPowerTypeAC;
            } else if (stringsAreEqual(currentState, CFSTR(kIOPSBatteryPowerValue))) {
                status = GSPowerTypeBattery;
            } else {
                status = GSPowerTypeUnknown;
            }
        }
    }
    
cleanup:
    CFRelease(list);
    CFRelease(blob);
    
    return status;
}

static void powerSourceChanged(void *context) {
    GSPower *powerSourceMonitor = (__bridge GSPower *)context;
    
    [powerSourceMonitor powerSourceChanged:getCurrentPowerSource()];
}

void registerPowerSourceNotification(GSPower *powerSourceMonitor) {
    CFRunLoopSourceRef loopSource = IOPSNotificationCreateRunLoopSource(powerSourceChanged, (__bridge void *)powerSourceMonitor);
    
    if (loopSource) {
        CFRunLoopAddSource(CFRunLoopGetCurrent(), loopSource, kCFRunLoopDefaultMode);
        CFRelease(loopSource);
    } else {
        GTMLoggerDebug(@"Creating RunLoop failed!\n");
    }
}

@implementation GSPower

@synthesize delegate;

- (GSPower *)initWithDelegate:(id<GSPowerDelegate>)object {
    if ((self = [super init])) {
        self.delegate = object;
        
        registerPowerSourceNotification(self);
    }
    
    return self;
}

- (GSPowerType)currentPowerSource {
    return getCurrentPowerSource();
}

- (void)powerSourceChanged:(GSPowerType)powerSource {
    if ([delegate respondsToSelector:@selector(powerSourceChanged:)]) {
        [delegate powerSourceChanged:powerSource];
    }
}

@end
