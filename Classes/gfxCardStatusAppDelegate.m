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

#define kHasSeenOneTimeNotificationKey @"hasSeenVersionTwoMessage"

@implementation gfxCardStatusAppDelegate

@synthesize menuController;

#pragma mark - Initialization

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    prefs = [PrefsController sharedInstance];
    
    if (![GSMux switcherOpen]) {
        GTMLoggerError(@"Can't open connection to AppleGraphicsControl. This probably isn't a gfxCardStatus-compatible machine.");
        
        [GSNotifier showUnsupportedMachineMessage];
        [menuController quit:self];
    } else {
        GTMLoggerInfo(@"GPUs present: %@", [GSGPU getGPUNames]);
        GTMLoggerInfo(@"Integrated GPU name: %@", [GSGPU integratedGPUName]);
        GTMLoggerInfo(@"Discrete GPU name: %@", [GSGPU discreteGPUName]);
    }
    
    // All the things (notifications)!
    [GSGPU registerForGPUChangeNotifications:self];
    NSNotificationCenter *center = [[NSWorkspace sharedWorkspace] notificationCenter];
    [center addObserver:self
               selector:@selector(handleWake:)
                   name:NSWorkspaceDidWakeNotification
                 object:nil];
    
    // Initialize the menu bar icon and hook the menu up to it.
    [menuController setupMenu];
    
    // Show the one-time startup notification asking users to be kind and donate
    // if they like gfxCardStatus. Then make it go away forever.
    if (![prefs boolForKey:kHasSeenOneTimeNotificationKey]) {
        [GSNotifier showOneTimeNotification];
        [prefs setBool:YES forKey:kHasSeenOneTimeNotificationKey];
    }
    
    // Set up Growl notifications regardless of whether or not we're supposed
    // to Growl.
    [GrowlApplicationBridge setGrowlDelegate:[GSNotifier sharedInstance]];
    
    // FIXME: hook up pref directly to updater.automaticallyChecksForUpdates
    // Check for updates if the user has them enabled.
    if ([prefs shouldCheckForUpdatesOnStartup])
        [updater checkForUpdatesInBackground];
}

#pragma mark - GSGPUDelegate protocol

- (void)GPUDidChangeTo:(GSGPUType)gpu
{
    [menuController updateMenu];
    
    // FIXME: Implement
}

#pragma mark - NSNotificationCenter notifications

- (void)handleWake:(NSNotification *)notification
{
    GTMLoggerDebug(@"Wake notification! %@", notification);
    // FIXME: Implement
//    [self performSelector:@selector(delayedPowerSourceCheck) withObject:nil afterDelay:7.0];
}

#pragma mark - Menu Actions

//- (void)menuWillOpen:(NSMenu *)menu {
//    // white image when menu is open
//    if ([prefs shouldUseImageIcons]) {
//        [statusItem setImage:[NSImage imageNamed:[[[statusItem image] name] stringByAppendingString:@"-white.png"]]];
//    }
//}
//
//- (void)menuDidClose:(NSMenu *)menu {
//    // black image when menu is closed
//    if ([prefs shouldUseImageIcons]) {
//        [statusItem setImage:[NSImage imageNamed:[[[statusItem image] name] stringByReplacingOccurrencesOfString:@"-white" withString:@".png"]]];
//    }
//}

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
