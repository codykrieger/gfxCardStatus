//
//  gfxCardStatusAppDelegate.m
//  gfxCardStatus
//
//  Created by Cody Krieger on 4/22/10.
//  Copyright 2010 Cody Krieger. All rights reserved.
//

#import "gfxCardStatusAppDelegate.h"
#import "systemProfiler.h"
#import "switcher.h"
#import "proc.h"
#import "NSAttributedString+Hyperlink.h"

#pragma mark Power Source & Switcher Helpers
#pragma mark -

BOOL canLog = NO;

// helper to get preference key from PowerSource enum
static inline NSString *keyForPowerSource(PowerSource powerSource) {
    return ((powerSource == psBattery) ? kGPUSettingBattery : kGPUSettingACAdaptor);
}

// helper to return current mode
switcherMode switcherGetMode() {
    if (switcherUseDynamicSwitching()) return modeDynamicSwitching;
    NSDictionary *profile = getGraphicsProfile();
    return ([(NSNumber *)[profile objectForKey:@"usingIntegrated"] boolValue] ? modeForceIntegrated : modeForceDiscrete);
}

@implementation gfxCardStatusAppDelegate

#pragma mark Initialization
#pragma mark -

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    prefs = [PrefsController sharedInstance];
    
    // initialize driver and process listing
    canLog = [prefs shouldLogToConsole];
    if (!switcherOpen()) Log(@"Can't open driver");
    if (!procInit()) Log(@"Can't obtain I/O Kit's master port");
    
    // localization
    NSString *version = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
    [versionItem setTitle:[Str(@"About") stringByReplacingOccurrencesOfString:@"%%" withString:version]];
    NSArray* localized = [[NSArray alloc] initWithObjects:updateItem, preferencesItem, quitItem, switchGPUs, integratedOnly, 
                          discreteOnly, dynamicSwitching, dependentProcesses, processList, aboutWindow, aboutClose, nil];
    for (NSButton *loc in localized) {
        [loc setTitle:Str([loc title])];
    }
    [localized release];
    
    // set up growl notifications
    if ([prefs shouldGrowl]) [GrowlApplicationBridge setGrowlDelegate:self];
    
    // check for updates if user has them enabled
    if ([prefs shouldCheckForUpdatesOnStartup]) [updater checkForUpdatesInBackground];
    
    // status item
    [statusMenu setDelegate:self];
    statusItem = [[[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength] retain];
    [statusItem setMenu:statusMenu];
    [statusItem setHighlightMode:YES];
    
    // v2.0 alert
    if (![prefs boolForKey:@"hasSeenVersionTwoMessage"]) {
        NSAlert *versionInfo = [[NSAlert alloc] init];
        [versionInfo setMessageText:@"Thanks for downloading gfxCardStatus!"];
        [versionInfo setInformativeText:@"If you find it useful, please consider donating to support development and hosting costs. You can find the donate link, and the FAQ page (which you should REALLY read) at the gfxCardStatus website:"];
        NSTextView *accessory = [[NSTextView alloc] initWithFrame:NSMakeRect(0,0,300,15)];
        [accessory insertText:[NSAttributedString hyperlinkFromString:@"http://codykrieger.com/gfxCardStatus" 
                                                              withURL:[NSURL URLWithString:@"http://codykrieger.com/gfxCardStatus"]]];
        [accessory setEditable:NO];
        [accessory setDrawsBackground:NO];
        [versionInfo setAccessoryView:accessory];
        [versionInfo addButtonWithTitle:@"Don't show this again!"];
        [versionInfo runModal];
        [versionInfo release];
        [accessory release];
        
        [prefs setBool:YES forKey:@"hasSeenVersionTwoMessage"];
    }
    
    // notifications
    NSNotificationCenter *defaultNotifications = [NSNotificationCenter defaultCenter];
    [defaultNotifications addObserver:self selector:@selector(handleNotification:)
                                   name:NSApplicationDidChangeScreenParametersNotification object:nil];
    [defaultNotifications addObserver:self selector:@selector(handleWake:)
                                 name:NSWorkspaceDidWakeNotification object:nil];
    
    // identify current gpu and set up menus accordingly
    NSDictionary *profile = getGraphicsProfile();
    if ([(NSNumber *)[profile objectForKey:@"unsupported"] boolValue]) {
        usingIntegrated = NO;
        NSAlert *alert = [NSAlert alertWithMessageText:@"You are using a system that gfxCardStatus does not support. Please ensure that you are using a MacBook Pro with dual GPUs." 
                                         defaultButton:@"Oh, I see." alternateButton:nil otherButton:nil informativeTextWithFormat:@""];
        [alert runModal];
    } else {
        usingIntegrated = [(NSNumber *)[profile objectForKey:@"usingIntegrated"] boolValue];
    }
    
    integratedString = [(NSString *)[profile objectForKey:@"integratedString"] copy];
    discreteString = [(NSString *)[profile objectForKey:@"discreteString"] copy];
    
    Log(@"Fetched machine profile: %@", profile);
    
    [switchGPUs setHidden:![prefs usingLegacy]];
    [integratedOnly setHidden:[prefs usingLegacy]];
    [discreteOnly setHidden:[prefs usingLegacy]];
    [dynamicSwitching setHidden:[prefs usingLegacy]];
    if ([prefs usingLegacy]) {
//        integratedString = @"NVIDIA® GeForce 9400M";
//        discreteString = @"NVIDIA® GeForce 9600M GT";
    } else {
        BOOL dynamic = switcherUseDynamicSwitching();
        [integratedOnly setState:(!dynamic && usingIntegrated) ? NSOnState : NSOffState];
        [discreteOnly setState:(!dynamic && !usingIntegrated) ? NSOnState : NSOffState];
        [dynamicSwitching setState:dynamic ? NSOnState : NSOffState];
        
//        integratedString = @"Intel® HD Graphics";
//        discreteString = @"NVIDIA® GeForce GT 330M";
    }
    
    canPreventSwitch = YES;
    
    canGrowl = NO;
    [self updateMenu];
    
    // only resture last mode if preference is set, and we're NOT using power source-based switching
    if ([prefs shouldRestoreStateOnStartup] && ![prefs shouldUsePowerSourceBasedSwitching] && ![prefs usingLegacy]) {
        Log(@"Restoring last used mode (%i)...", [prefs shouldRestoreToMode]);
        id modeItem;
        switch ([prefs shouldRestoreToMode]) {
            case 0:
                modeItem = integratedOnly;
                break;
            case 1:
                modeItem = discreteOnly;
                break;
            case 2:
                modeItem = dynamicSwitching;
                break;
        }
        
        [self setMode:modeItem];
    }
    canGrowl = YES;
    
    powerSourceMonitor = [PowerSourceMonitor monitorWithDelegate:self];
    lastPowerSource = -1; // uninitialized
    
    // check current power source and load preference for it
    [self powerSourceChanged:powerSourceMonitor.currentPowerSource];
}

- (NSDictionary *)registrationDictionaryForGrowl {
    return [NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"Growl Registration Ticket" ofType:@"growlRegDict"]];
}

- (void)handleNotification:(NSNotification *)notification {
    // Notification observer
    // NOTE: If we open the menu while a slow app like Interface Builder is loading, we have the icon not changing
    // TODO: Look into way AirPort menu item handles updating while open
    
    Log(@"The following notification has been triggered:\n%@", notification);
    [self updateMenu];
    
    // verify state
    [self performSelector:@selector(checkCardState) withObject:nil afterDelay:2.0];
}

- (void)handleWake:(NSNotification *)notification {
    [self performSelector:@selector(delayedPowerSourceCheck) withObject:nil afterDelay:7.0];
}

- (void)delayedPowerSourceCheck {
    [self powerSourceChanged:powerSourceMonitor.currentPowerSource];
}

#pragma mark Menu Actions
#pragma mark -

- (void)menuNeedsUpdate:(NSMenu *)menu {
    //[self updateMenu];
    [self updateProcessList];
}

- (void)menuWillOpen:(NSMenu *)menu {
    // white image when menu is open
    [statusItem setImage:[NSImage imageNamed:[[[statusItem image] name] stringByAppendingString:@"-white.png"]]];
}

- (void)menuDidClose:(NSMenu *)menu {
    // black image when menu is closed
    [statusItem setImage:[NSImage imageNamed:[[[statusItem image] name] stringByReplacingOccurrencesOfString:@"-white" withString:@".png"]]];
}

- (IBAction)openPreferences:(id)sender {
    [prefs openPreferences];
}

- (IBAction)openAbout:(id)sender {
    // open window and force to the front
    [aboutWindow makeKeyAndOrderFront:nil];
    [aboutWindow orderFrontRegardless];
    [aboutWindow center];
}

- (IBAction)closeAbout:(id)sender {
    [aboutWindow close];
}

- (IBAction)setMode:(id)sender {
    // legacy cards
    if (sender == switchGPUs) {
        Log(@"Switching GPUs...");
        switcherSetMode(modeToggleGPU);
        return;
    }
    
    // current cards
    if ([sender state] == NSOnState) return;
    
    BOOL retval = NO;
    if (sender == integratedOnly) {
        Log(@"Setting Integrated only...");
        retval = switcherSetMode(modeForceIntegrated);
    }
    if (sender == discreteOnly) { 
        Log(@"Setting NVIDIA only...");
        retval = switcherSetMode(modeForceDiscrete);
    }
    if (sender == dynamicSwitching) {
        Log(@"Setting dynamic switching...");
        retval = switcherSetMode(modeDynamicSwitching);
    }
    
    // only change status in case of success
    if (retval) {
        [integratedOnly setState:(sender == integratedOnly ? NSOnState : NSOffState)];
        [discreteOnly setState:(sender == discreteOnly ? NSOnState : NSOffState)];
        [dynamicSwitching setState:(sender == dynamicSwitching ? NSOnState : NSOffState)];
        
        // delayed double-check
        [self performSelector:@selector(checkCardState) withObject:nil afterDelay:5.0];
    }
}

- (IBAction)openApplicationURL:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://codykrieger.com/gfxCardStatus"]];
}

- (IBAction)quit:(id)sender {
    [[NSApplication sharedApplication] terminate:self];
}

- (void)updateMenu {
    BOOL integrated = switcherUseIntegrated();
    Log(@"Updating status...");
    
    // prevent GPU from switching back after apps quit
    if (!integrated && ![prefs usingLegacy] && [integratedOnly state] > 0 && canPreventSwitch) {
        Log(@"Preventing switch to Discrete GPU. Setting canPreventSwitch to NO so that this doesn't get stuck in a loop, changing in 5 seconds...");
        canPreventSwitch = NO;
        [self setMode:integratedOnly];
        [NSTimer scheduledTimerWithTimeInterval:5 target:self selector:@selector(shouldPreventSwitch) userInfo:nil repeats:NO];
        return;
    }
    
    // update icon and labels according to selected GPU
    NSString* cardString = integrated ? integratedString : discreteString;
//    if ([prefs usingLegacy])
//        [statusItem setImage:[NSImage imageNamed:integrated ? @"integrated-3.png" : @"discrete-3.png"]];
//    else
    [statusItem setImage:[NSImage imageNamed:integrated ? @"integrated-3.png" : @"discrete-3.png"]];
    
    [currentCard setTitle:[Str(@"Card") stringByReplacingOccurrencesOfString:@"%%" withString:cardString]];
    [currentPowerSource setTitle:[NSString stringWithFormat:@"Power Source: %@", (powerSourceMonitor.currentPowerSource == psBattery) ? @"Battery" : @"AC Adapter"]];
    
    if (integrated) Log(@"%@ in use. Sweet deal! More battery life.", integratedString);
    else Log(@"%@ in use. Bummer! Less battery life for you.", discreteString);
    
    if ([prefs shouldGrowl] && canGrowl && usingIntegrated != integrated) {
        NSString *msg  = [NSString stringWithFormat:@"%@ %@", cardString, Str(@"GrowlSwitch")];
        NSString *name = integrated ? @"switchedToIntegrated" : @"switchedToDiscrete";
        [GrowlApplicationBridge notifyWithTitle:Str(@"GrowlGPUChanged") description:msg notificationName:name iconData:nil priority:0 isSticky:NO clickContext:nil];
    }
    
    usingIntegrated = integrated;
    if (!integrated) [self updateProcessList];
}

- (void)updateProcessList {
    for (NSMenuItem *mi in [statusMenu itemArray]) {
        if ([mi indentationLevel] > 0 && ![mi isEqual:processList]) [statusMenu removeItem:mi];
    }
    
    // if we're on Integrated (or using a 9400M/9600M GT model), no need to display/update the list
    BOOL procList = !usingIntegrated && ![prefs usingLegacy];
    [processList setHidden:!procList];
    [processesSeparator setHidden:!procList];
    [dependentProcesses setHidden:!procList];
    if (!procList) return;
    
    Log(@"Updating process list...");
    
    // find out if an external monitor is forcing the 330M on
    BOOL usingExternalDisplay = NO;
    CGDirectDisplayID displays[8];
    CGDisplayCount displayCount = 0;
    if (CGGetOnlineDisplayList(8, displays, &displayCount) == noErr) {
        for (int i = 0; i < displayCount; i++) {
            if ( ! CGDisplayIsBuiltin(displays[i])) {
                NSMenuItem *externalDisplay = [[[NSMenuItem alloc] initWithTitle:@"External Display" action:nil keyEquivalent:@""] autorelease];
                [externalDisplay setIndentationLevel:1];
                [statusMenu insertItem:externalDisplay atIndex:([statusMenu indexOfItem:processList] + 1)];
                usingExternalDisplay = YES;
            }
        }
    }
    
    NSMutableDictionary* procs = [[NSMutableDictionary alloc] init];
    if (!procGet(procs)) Log(@"Can't obtain I/O Kit's root service");
    
    [processList setHidden:([procs count] > 0 || usingExternalDisplay)];
    if ([procs count]==0) Log(@"We're using the Discrete card, but no process requires it. An external monitor may be connected, or we may be in Discrete Only mode.");
    
    for (NSString* appName in [procs allValues]) {
        NSMenuItem *appItem = [[NSMenuItem alloc] initWithTitle:appName action:nil keyEquivalent:@""];
        [appItem setIndentationLevel:1];
        [statusMenu insertItem:appItem atIndex:([statusMenu indexOfItem:processList] + 1)];
        [appItem release];
    }
    
    [procs release];
}

#pragma mark Helpers
#pragma mark -

- (NSMenuItem *)senderForMode:(switcherMode)mode {
    // convert switcher mode to a menu item (consumed by setMode:)
    
    switch (mode) {
        case modeForceIntegrated:
            return integratedOnly;
        case modeForceDiscrete:
            return discreteOnly;
        case modeDynamicSwitching:
            return dynamicSwitching;
        case modeToggleGPU:
            // warnings suck. all your base are belong to us.
            break;
    }
    
    return dynamicSwitching;
}

- (void)checkCardState {
    // it seems right after waking from sleep, locking to single GPU will fail (even if the return value is correct)
    // this is a temporary workaround to double-check the status
    
    switcherMode currentMode = switcherGetMode(); // actual current mode
    NSMenuItem *activeCard = [self senderForMode:currentMode]; // corresponding menu item
    
    // check if its consistent with menu state
    if ([activeCard state] != NSOnState && ![prefs usingLegacy]) {
        Log(@"Inconsistent menu state and active card, forcing retry");
        
        // set menu item to reflect actual status
        [integratedOnly setState:NSOffState];
        [discreteOnly setState:NSOffState];
        [dynamicSwitching setState:NSOffState];
        [activeCard setState:NSOnState];
    }
    
    if ([integratedOnly state] > 0) {
        [prefs setLastMode:0];
    } else if ([discreteOnly state] > 0) {
        [prefs setLastMode:1];
    } else if ([dynamicSwitching state] > 0) {
        [prefs setLastMode:2];
    }
    
    // this is being problematic
    // lastPowerSource = -1; // set to uninitialized
    [self powerSourceChanged:powerSourceMonitor.currentPowerSource];
}

- (void)powerSourceChanged:(PowerSource)powerSource {
    if (powerSource == lastPowerSource) {
        //Log(@"Power source unchanged, false alarm (maybe a wake from sleep?)");
        return;
    }
    
    Log(@"Power source changed: %d => %d (%@)", lastPowerSource, powerSource, (powerSource == psBattery ? @"Battery" : @"AC Adapter"));
    lastPowerSource = powerSource;
    
    if ([prefs shouldUsePowerSourceBasedSwitching]) {
        switcherMode newMode = [prefs modeForPowerSource:keyForPowerSource(powerSource)];
        
        if (![prefs usingLegacy]) {
            Log(@"Using a newer machine, setting appropriate mode based on power source...");
            [self setMode:[self senderForMode:newMode]];
        } else {
            Log(@"Using a legacy machine, setting appropriate mode based on power source...");
            Log(@"usingIntegrated=%i, newMode=%i", usingIntegrated, newMode);
            if ((usingIntegrated && newMode == 1) || (!usingIntegrated && newMode == 0)) {
                [self setMode:switchGPUs];
            }
        }
    }
    
    [self updateMenu];
}

- (void)shouldPreventSwitch {
    Log(@"Can prevent switching again.");
    canPreventSwitch = YES;
}

- (void)dealloc {
    procFree(); // Free processes listing buffers
    switcherClose(); // Close driver
    
    [statusItem release];
    [super dealloc];
}

@end
