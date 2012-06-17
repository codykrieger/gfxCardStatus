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

static BOOL _stringsAreEqual(CFStringRef a, CFStringRef b);
static GSPowerType _getCurrentPowerSource();
static void _powerSourceChanged(void *context);
static void _registerPowerSourceNotification(GSPower *powerSourceMonitor);

#pragma mark - Static C methods

static BOOL _stringsAreEqual(CFStringRef a, CFStringRef b)
{
    if (a == nil || b == nil) {
        return NO;
    }
    
    return (CFStringCompare(a, b, 0) == kCFCompareEqualTo);
}

static GSPowerType _getCurrentPowerSource()
{
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
        
        if (_stringsAreEqual(CFDictionaryGetValue(description, CFSTR(kIOPSTransportTypeKey)), CFSTR(kIOPSInternalType))) {
            CFStringRef currentState = CFDictionaryGetValue(description, CFSTR(kIOPSPowerSourceStateKey));
            
            if (_stringsAreEqual(currentState, CFSTR(kIOPSACPowerValue))) {
                status = GSPowerTypeAC;
            } else if (_stringsAreEqual(currentState, CFSTR(kIOPSBatteryPowerValue))) {
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

static void _powerSourceChanged(void *context)
{
    GSPower *powerSourceMonitor = (__bridge GSPower *)context;
    
    [powerSourceMonitor powerSourceChanged:_getCurrentPowerSource()];
}

void _registerPowerSourceNotification(GSPower *powerSourceMonitor)
{
    CFRunLoopSourceRef loopSource = IOPSNotificationCreateRunLoopSource(_powerSourceChanged, (__bridge void *)powerSourceMonitor);
    
    if (loopSource) {
        CFRunLoopAddSource(CFRunLoopGetCurrent(), loopSource, kCFRunLoopDefaultMode);
        CFRelease(loopSource);
    } else {
        GTMLoggerDebug(@"Creating RunLoop failed!");
    }
}

@implementation GSPower

@synthesize delegate;

#pragma mark - Initializers

- (GSPower *)initWithDelegate:(id<GSPowerDelegate>)object
{
    if (!(self = [super init]))
        return nil;
        
    self.delegate = object;

    _registerPowerSourceNotification(self);
    
    return self;
}

#pragma mark - GSPower API

- (GSPowerType)currentPowerSource
{
    return _getCurrentPowerSource();
}

- (void)powerSourceChanged:(GSPowerType)powerSource
{
    if ([delegate respondsToSelector:@selector(powerSourceChanged:)]) {
        [delegate powerSourceChanged:powerSource];
    }
}

@end
