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

@end
