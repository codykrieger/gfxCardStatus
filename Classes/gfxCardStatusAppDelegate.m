//
//  gfxCardStatusAppDelegate.m
//  gfxCardStatus
//
//  Created by Cody Krieger on 4/22/10.
//  Copyright 2010 Cody Krieger. All rights reserved.
//

#import "gfxCardStatusAppDelegate.h"
#import "NSAttributedString+Hyperlink.h"
#import "GeneralPreferencesViewController.h"
#import "AdvancedPreferencesViewController.h"
#import "GSProcess.h"
#import "GSMux.h"
#import "GSNotifier.h"

#import <ReactiveCocoa/ReactiveCocoa.h>

#define kHasSeenOneTimeNotificationKey @"hasSeenVersionTwoMessage"

#define kShouldCheckForUpdatesOnStartupKeyPath @"prefsDict.shouldCheckForUpdatesOnStartup"

@implementation gfxCardStatusAppDelegate

@synthesize updater;
@synthesize menuController;

#pragma mark - Initialization

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // Initialize the preferences object and set default preferences if this is
    // a first-time run.
    _prefs = [GSPreferences sharedInstance];
    
    // Initialize the power object and start listening for power source change
    // notifications. This object takes care of the actual switching if
    // necessary.
    _power = [GSPower sharedInstance];
    
    // Attempt to open a connection to AppleGraphicsControl.
    if (![GSMux switcherOpen]) {
        GTMLoggerError(@"Can't open connection to AppleGraphicsControl. This probably isn't a gfxCardStatus-compatible machine.");
        
        [GSNotifier showUnsupportedMachineMessage];
        [menuController quit:self];
    } else {
        GTMLoggerInfo(@"GPUs present: %@", [GSGPU getGPUNames]);
        GTMLoggerInfo(@"Integrated GPU name: %@", [GSGPU integratedGPUName]);
        GTMLoggerInfo(@"Discrete GPU name: %@", [GSGPU discreteGPUName]);
    }
    
    // Now accepting GPU change notifications! Apply at your nearest GSGPU today.
    [GSGPU registerForGPUChangeNotifications:self];
    
    // Initialize the menu bar icon and hook the menu up to it.
    [menuController setupMenu];
    
    // Show the one-time startup notification asking users to be kind and donate
    // if they like gfxCardStatus. Then make it go away forever.
    if (![_prefs boolForKey:kHasSeenOneTimeNotificationKey]) {
        [GSNotifier showOneTimeNotification];
        [_prefs setBool:YES forKey:kHasSeenOneTimeNotificationKey];
    }
    
    // Set up Growl notifications regardless of whether or not we're supposed
    // to Growl.
    [GrowlApplicationBridge setGrowlDelegate:[GSNotifier sharedInstance]];
    
    // Hook up the check for updates on startup preference directly to the
    // automaticallyChecksForUpdates property on the SUUpdater.
    [[_prefs rac_subscribableForKeyPath:kShouldCheckForUpdatesOnStartupKeyPath onObject:self] subscribeNext:^(id x) {
        GTMLoggerDebug(@"Check for updates on startup value changed: %@", x);
        updater.automaticallyChecksForUpdates = [x boolValue];
    }];
    
    // Check for updates if the user has them enabled.
    if ([_prefs shouldCheckForUpdatesOnStartup])
        [updater checkForUpdatesInBackground];
}

#pragma mark - GSGPUDelegate protocol

- (void)GPUDidChangeTo:(GSGPUType)gpu
{
    [menuController updateMenu];
    [GSNotifier showGPUChangeNotification:gpu];
}

#pragma mark - Helpers

//- (NSMenuItem *)senderForMode:(GSSwitcherMode)mode {
//    // convert switcher mode to a menu item (consumed by setMode:)
//    
//    switch (mode) {
//        case GSSwitcherModeForceIntegrated:
//            return integratedOnly;
//        case GSSwitcherModeForceDiscrete:
//            return discreteOnly;
//        case GSSwitcherModeDynamicSwitching:
//            return dynamicSwitching;
//        case GSSwitcherModeToggleGPU:
//            // warnings suck. all your base are belong to us.
//            break;
//    }
//    
//    return dynamicSwitching;
//}
//
//- (void)checkCardState {
//    // it seems right after waking from sleep, locking to single GPU will fail (even if the return value is correct)
//    // this is a temporary workaround to double-check the status
//    
//    GSSwitcherMode currentMode = GSSwitcherModeDynamicSwitching; //[GSProcess switcherGetMode]; // actual current mode
//    NSMenuItem *activeCard = [self senderForMode:currentMode]; // corresponding menu item
//    
//    // check if we're consistent with menu state
//    if ([activeCard state] != NSOnState && ![state usingLegacy]) {
//        GTMLoggerDebug(@"Inconsistent menu state and active card, forcing retry");
//        
//        // set menu item to reflect actual status
//        [integratedOnly setState:NSOffState];
//        [discreteOnly setState:NSOffState];
//        [dynamicSwitching setState:NSOffState];
//        [activeCard setState:NSOnState];
//    }
//    
//    if ([integratedOnly state] > 0) {
//        [prefs setLastMode:0];
//    } else if ([discreteOnly state] > 0) {
//        [prefs setLastMode:1];
//    } else if ([dynamicSwitching state] > 0) {
//        [prefs setLastMode:2];
//    }
//    
//    // this is being problematic
//    // lastPowerSource = -1; // set to uninitialized
//    
////    [self powerSourceChanged:powerSourceMonitor.currentPowerSource];
//}

//- (void)powerSourceChanged:(PowerSource)powerSource {
//    if (powerSource == lastPowerSource) {
//        //DLog(@"Power source unchanged, false alarm (maybe a wake from sleep?)");
//        return;
//    }
//    
//    GTMLoggerDebug(@"Power source changed: %d => %d (%@)", 
//                   lastPowerSource, 
//                   powerSource, 
//                   (powerSource == psBattery ? @"Battery" : @"AC Adapter"));
//    lastPowerSource = powerSource;
//    
//    if ([prefs shouldUsePowerSourceBasedSwitching]) {
//        GSSwitcherMode newMode = [prefs modeForPowerSource:
//                                [GSProcess keyForPowerSource:powerSource]];
//        
//        if (![state usingLegacy]) {
//            GTMLoggerDebug(@"Using a newer machine, setting appropriate mode based on power source...");
//            [menuController setMode:[self senderForMode:newMode]];
//        } else {
//            GTMLoggerDebug(@"Using a legacy machine, setting appropriate mode based on power source...");
//            GTMLoggerInfo(@"Power source-based switch: usingIntegrated=%i, newMode=%i", [state usingIntegrated], newMode);
//            if (([state usingIntegrated] && newMode == 1) || (![state usingIntegrated] && newMode == 0)) {
//                [menuController setMode:switchGPUs];
//            }
//        }
//    }
//    
//    [self updateMenu];
//}

@end
