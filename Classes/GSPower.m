//
//  GSPower.m
//  gfxCardStatus
//
//  Created by Cody Krieger on 6/12/12.
//  Copyright (c) 2012 Cody Krieger. All rights reserved.
//

#import "GSPower.h"
#import "GSMux.h"
#import "GSGPU.h"

#include <IOKit/IOKitLib.h>
#include <IOKit/ps/IOPSKeys.h>
#include <IOKit/ps/IOPowerSources.h>
#include <ReactiveCocoa/ReactiveCocoa.h>

#define kShouldUsePowerSourceBasedSwitchingKeyPath @"prefsDict.shouldUsePowerSourceBasedSwitching"

#define kPowerSourceChangedNotificationDelay (10)

static BOOL _stringsAreEqual(CFStringRef a, CFStringRef b);
static GSPowerType _getCurrentPowerSource();
static void _powerSourceChanged(void *context);
static void _registerPowerSourceNotification(GSPower *powerSourceMonitor);

static BOOL _enabled = NO;
static GSPowerType _currentPowerSource = GSPowerTypeUnknown;

#pragma mark - Static C methods

static BOOL _stringsAreEqual(CFStringRef a, CFStringRef b)
{
    if (a == nil || b == nil)
        return NO;
    
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
            
            if (_stringsAreEqual(currentState, CFSTR(kIOPSACPowerValue)))
                status = GSPowerTypeAC;
            else if (_stringsAreEqual(currentState, CFSTR(kIOPSBatteryPowerValue)))
                status = GSPowerTypeBattery;
            else
                status = GSPowerTypeUnknown;
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
    
//    [powerSourceMonitor powerSourceChanged:_getCurrentPowerSource()];
    [powerSourceMonitor performSelector:@selector(powerSourceChanged:) withObject:@(_getCurrentPowerSource()) afterDelay:kPowerSourceChangedNotificationDelay];
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

#pragma mark - Initializers

- (id)init
{
    if (!(self = [super init]))
        return nil;
    
    _prefs = [GSPreferences sharedInstance];
    
    // Register for power source change notifications
    _registerPowerSourceNotification(self);
    
    // Also register for system wake notifications so we can check our power
    // source and change modes if appropriate.
    NSNotificationCenter *center = [[NSWorkspace sharedWorkspace] notificationCenter];
    [center addObserver:self
               selector:@selector(handleWake:)
                   name:NSWorkspaceDidWakeNotification
                 object:nil];
    
    _enabled = _prefs.shouldUsePowerSourceBasedSwitching;
    [[_prefs rac_subscribableForKeyPath:kShouldUsePowerSourceBasedSwitchingKeyPath onObject:self] subscribeNext:^(id x) {
        GTMLoggerDebug(@"Should use power source-based switching value changed: %@", x);
        _enabled = [x boolValue];
    }];
    
    return self;
}

+ (GSPower *)sharedInstance
{
    static dispatch_once_t pred = 0;
    __strong static GSPower *_sharedObject = nil;
    dispatch_once(&pred, ^{
        _sharedObject = [[self alloc] init];
    });
    return _sharedObject;
}

#pragma mark - GSPower API

- (GSPowerType)currentPowerSource
{
    return _getCurrentPowerSource();
}

- (void)powerSourceChanged:(GSPowerType)type
{
    GSPowerType oldPowerSource = _currentPowerSource;
    
    // If the current power source is already something known, we don't want to
    // kick it over to unknown, because the next time we get a valid power
    // source change notification, we'll switch, probably, to the current mode.
    // And that might trigger a notification, which is obnoxious and stupid. So
    // we won't do that.
    if (_currentPowerSource != type && type != GSPowerTypeUnknown)
        _currentPowerSource = type;
    
    // Make sure we don't do anything if we're not enabled.
    if (!_enabled || type == oldPowerSource)
        return;
    
    GTMLoggerInfo(@"Power source changed to: %d from %d", type, oldPowerSource);
    
    // We can't really change modes if we have no clue what power source we just
    // changed to.
    if (type == GSPowerTypeUnknown)
        return;
    
    GSPowerSourceBasedSwitchingMode mode = type == GSPowerTypeAC ? _prefs.modeForACAdapter : _prefs.modeForBattery;
    
    switch (mode) {
        case GSPowerSourceBasedSwitchingModeIntegrated:
            [GSMux setMode:GSSwitcherModeForceIntegrated];
            break;
            
        case GSPowerSourceBasedSwitchingModeDiscrete:
            [GSMux setMode:GSSwitcherModeForceDiscrete];
            break;
            
        case GSPowerSourceBasedSwitchingModeDynamic:
            [GSMux setMode:GSSwitcherModeDynamicSwitching];
            
            // We have to manually trigger a notification in case we're already
            // using the GPU that Dynamic Switching would kick us over to,
            // because in that case, we won't receive a display change
            // notification from the OS.
            [GSGPU fireManualChangeNotification];
            break;
    }
}

#pragma mark - NSNotificationCenter notifications

- (void)handleWake:(NSNotification *)notification
{
    GTMLoggerInfo(@"Wake notification! %@", notification);

    // Only notify ourselves if we're using a different power source now.
    GSPowerType reallyCurrentPowerSource = _getCurrentPowerSource();
    if (_currentPowerSource != reallyCurrentPowerSource)
        [self powerSourceChanged:reallyCurrentPowerSource];
}

@end
