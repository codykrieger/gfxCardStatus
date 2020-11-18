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

#pragma mark - Initialization

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // Initialize the preferences object and set default preferences if this is
    // a first-time run.
    _prefs = [GSPreferences sharedInstance];

    // Attempt to open a connection to AppleGraphicsControl.
    if (![[GSMux defaultMux] switcherOpen]) {
        GSLogError(@"Can't open connection to AppleGraphicsControl. This probably isn't a gfxCardStatus-compatible machine.");
        
        [GSNotifier showUnsupportedMachineMessage];
        [_menuController quit:self];
    } else {
        GSLogInfo(@"GPUs present: %@", [GSGPU getGPUNames]);
        GSLogInfo(@"Integrated GPU name: %@", [GSGPU integratedGPUName]);
        GSLogInfo(@"Discrete GPU name: %@", [GSGPU discreteGPUName]);
        
        NSArray *args = [[NSProcessInfo processInfo] arguments];
        if ([args indexOfObject:@"--discrete"] != NSNotFound) {
            [[GSMux defaultMux] setMode:GSSwitcherModeForceDiscrete];
        } else if ([args indexOfObject:@"--integrated"] != NSNotFound) {
            [[GSMux defaultMux] setMode:GSSwitcherModeForceIntegrated];
        } else if ([args indexOfObject:@"--dynamic"] != NSNotFound) {
            [[GSMux defaultMux] setMode:GSSwitcherModeDynamicSwitching];
        } else if (![GSGPU isLegacyMachine]) {
            // Set the machine to dynamic switching to get it out of any kind of
            // weird state from the get go.
            [[GSMux defaultMux] setMode:GSSwitcherModeDynamicSwitching];
        }
    }

    // Now accepting GPU change notifications! Apply at your nearest GSGPU today.
    [GSGPU registerForGPUChangeNotifications:self];

    // Register with NSWorkspace for system shutdown notifications to ensure
    // proper termination in the event of system shutdown and/or user logout.
    // Goal is to ensure machine is set to default dynamic switching before shut down.
    NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
    [[workspace notificationCenter] addObserver:self
                                       selector:@selector(workspaceWillPowerOff:)
                                           name:NSWorkspaceWillPowerOffNotification
                                         object:workspace];

    // Initialize the menu bar icon and hook the menu up to it.
    [_menuController setupMenu];

    // Show the one-time startup notification asking users to be kind and donate
    // if they like gfxCardStatus. Then make it go away forever.
    if (![_prefs boolForKey:kHasSeenOneTimeNotificationKey]) {
        [GSNotifier showOneTimeNotification];
        [_prefs setBool:YES forKey:kHasSeenOneTimeNotificationKey];
    }

    // Hook up the check for updates on startup preference directly to the
    // automaticallyChecksForUpdates property on the SUUpdater.
    _updater.automaticallyChecksForUpdates = _prefs.shouldCheckForUpdatesOnStartup;

    // FIXME: Rip out ReactiveCocoa.
    [[_prefs rac_signalForKeyPath:kShouldCheckForUpdatesOnStartupKeyPath observer:self] subscribeNext:^(id x) {
        GSLogDebug(@"Check for updates on startup value changed: %@", x);
        self->_updater.automaticallyChecksForUpdates = [x boolValue];
    }];

    // Check for updates if the user has them enabled.
    if ([_prefs shouldCheckForUpdatesOnStartup])
        [_updater checkForUpdatesInBackground];
}

#pragma mark - Termination Notifications

- (void)applicationWillTerminate:(NSNotification *)aNotification
{
    // Set the machine to dynamic switching before shutdown to avoid machine restarting
    // stuck in a forced GPU mode.
    if (![GSGPU isLegacyMachine])
        [[GSMux defaultMux] setMode:GSSwitcherModeDynamicSwitching];

    GSLogDebug(@"Termination notification received. Going to Dynamic Switching.");
}

- (void)workspaceWillPowerOff:(NSNotification *)aNotification
{
    // Selector called in response to application termination notification from
    // NSWorkspace. Also implemented to avoid the machine shuting down in a forced
    // GPU state.
    [[NSApplication sharedApplication] terminate:self];
    GSLogDebug(@"NSWorkspaceWillPowerOff notification received. Terminating application.");
}

#pragma mark - GSGPUDelegate protocol

- (void)GPUDidChangeTo:(GSGPUType)gpu
{
    [_menuController updateMenu];
    [GSNotifier showGPUChangeNotification:gpu];
}

@end
