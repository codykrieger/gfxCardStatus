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

BOOL canLog = NO;

// helper to get preference key from PowerSource enum
static inline NSString *keyForPowerSource(PowerSource powerSource) {
    return ((powerSource == psBattery) ? kGPUSettingBattery : kGPUSettingACAdaptor);
}

// helper to return current mode
switcherMode switcherGetMode() {
    return (switcherUseDynamicSwitching() ? modeDynamicSwitching : (isUsingIntegratedGraphics(NULL) ? modeForceIntel : modeForceNvidia));
}

@implementation gfxCardStatusAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    prefs = [PrefsController sharedInstance];
    
    // initialize driver and process listing
    canLog = [prefs shouldLogToConsole];
    if (!switcherOpen()) Log(@"Can't open driver");
    if (!procInit()) Log(@"Can't obtain I/O Kit's master port");
    
    // localization
    NSString *version = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
    [versionItem setTitle:[Str(@"About") stringByReplacingOccurrencesOfString:@"%%" withString:version]];
    NSArray* localized = [[NSArray alloc] initWithObjects:updateItem, preferencesItem, quitItem, switchGPUs, intelOnly, 
                          nvidiaOnly, dynamicSwitching, dependentProcesses, processList, aboutWindow, aboutClose, nil];
    for (NSButton *loc in localized) {
        [loc setTitle:Str([loc title])];
    }
    [localized release];
    
    // set up growl notifications
    if ([prefs shouldGrowl])
        [GrowlApplicationBridge setGrowlDelegate:self];
    
    // check for updates if user has them enabled
    if ([prefs shouldCheckForUpdatesOnStartup])
        [updater checkForUpdatesInBackground];
    
    // status item
    [statusMenu setDelegate:self];
    statusItem = [[[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength] retain];
    [statusItem setMenu:statusMenu];
    [statusItem setHighlightMode:YES];
    
    NSNotificationCenter *defaultNotifications = [NSNotificationCenter defaultCenter];
    [defaultNotifications addObserver:self selector:@selector(handleNotification:)
                                   name:NSApplicationDidChangeScreenParametersNotification object:nil];
    
    // identify current gpu and set up menus accordingly
    usingIntegrated = isUsingIntegratedGraphics(&usingLegacy);
    [switchGPUs setHidden:!usingLegacy];
    [intelOnly setHidden:usingLegacy];
    [nvidiaOnly setHidden:usingLegacy];
    [dynamicSwitching setHidden:usingLegacy];
    if (usingLegacy) {
        Log(@"Looks like we're using an older 9400M/9600M GT system.");
        
        integratedString = @"NVIDIA® GeForce 9400M";
        discreteString = @"NVIDIA® GeForce 9600M GT";
    } else {
        BOOL dynamic = switcherUseDynamicSwitching();
        [intelOnly setState:(!dynamic && usingIntegrated) ? NSOnState : NSOffState];
        [nvidiaOnly setState:(!dynamic && !usingIntegrated) ? NSOnState : NSOffState];
        [dynamicSwitching setState:dynamic ? NSOnState : NSOffState];
        
        integratedString = @"Intel® HD Graphics";
        discreteString = @"NVIDIA® GeForce GT 330M";
    }
    
    canPreventSwitch = YES;
    
    canGrowl = NO;
    [self updateMenu];
    
    // only resture last mode if preference is set, and we're NOT using power source-based switching
    if ([prefs shouldRestoreStateOnStartup] && ![prefs shouldUsePowerSourceBasedSwitching] && !usingLegacy) {
        Log(@"Restoring last used mode (%i)...", [prefs shouldRestoreToMode]);
        id modeItem;
        switch ([prefs shouldRestoreToMode]) {
            case 0:
                modeItem = intelOnly;
                break;
            case 1:
                modeItem = nvidiaOnly;
                break;
            case 2:
                modeItem = dynamicSwitching;
                break;
        }
        
        [self setMode:modeItem];
    }
    canGrowl = YES;
    
    // monitor power source
    // currently only works for 2010 MBPs
    if (!usingLegacy) {
        powerSourceMonitor = [PowerSourceMonitor monitorWithDelegate:self];
        lastPowerSource = -1; // uninitialized
        
        // check current power source and load preference for it
        [self powerSourceChanged:powerSourceMonitor.currentPowerSource];
    } else {
        // disable these controls for legacy users until power source switching works for them
        [currentPowerSource setHidden:YES];
        //[gpuOnAdaptor setEnabled:NO];
//        [gpuOnBattery setEnabled:NO];
//        [usePowerSourceBasedSwitching setEnabled:NO];
    }
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
    if (sender == intelOnly) {
        Log(@"Setting Intel only...");
        retval = switcherSetMode(modeForceIntel);
    }
    if (sender == nvidiaOnly) { 
        Log(@"Setting NVIDIA only...");
        retval = switcherSetMode(modeForceNvidia);
    }
    if (sender == dynamicSwitching) {
        Log(@"Setting dynamic switching...");
        retval = switcherSetMode(modeDynamicSwitching);
    }
    
    // only change status in case of success
    if (retval) {
        [intelOnly setState:(sender == intelOnly ? NSOnState : NSOffState)];
        [nvidiaOnly setState:(sender == nvidiaOnly ? NSOnState : NSOffState)];
        [dynamicSwitching setState:(sender == dynamicSwitching ? NSOnState : NSOffState)];
        
        // delayed double-check
        [self performSelector:@selector(checkCardState) withObject:nil afterDelay:5.0];
    }
}

- (void)handleNotification:(NSNotification *)notification {
    // Notification observer
    // NOTE: If we open the menu while a slow app like Interface Builder is loading, we have the icon not changing
    
    Log(@"The following notification has been triggered:\n%@", notification);
    [self updateMenu];
    
    // delayed double-check
    [self performSelector:@selector(checkCardState) withObject:nil afterDelay:5.0];
}

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

- (void)updateProcessList {
    for (NSMenuItem *mi in [statusMenu itemArray]) {
        if ([mi indentationLevel] > 0 && ![mi isEqual:processList]) [statusMenu removeItem:mi];
    }
    
    // if we're on Intel (or using a 9400M/9600M GT model), no need to display/update the list
    BOOL procList = !usingIntegrated && !usingLegacy;
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
                NSMenuItem *externalDisplay = [[NSMenuItem alloc] initWithTitle:@"External Display" action:nil keyEquivalent:@""];
                [externalDisplay setIndentationLevel:1];
                [statusMenu insertItem:externalDisplay atIndex:([statusMenu indexOfItem:processList] + 1)];
                usingExternalDisplay = YES;
            }
        }
    }
    
    NSMutableDictionary* procs = [[NSMutableDictionary alloc] init];
    if (!procGet(procs)) Log(@"Can't obtain I/O Kit's root service");
    
    [processList setHidden:([procs count] > 0 || usingExternalDisplay)];
    if ([procs count]==0) Log(@"We're using the NVIDIA® card, but no process requires it. An external monitor may be connected, or we may be in NVIDIA® Only mode.");
    
    for (NSString* appName in [procs allValues]) {
        NSMenuItem *appItem = [[NSMenuItem alloc] initWithTitle:appName action:nil keyEquivalent:@""];
        [appItem setIndentationLevel:1];
        [statusMenu insertItem:appItem atIndex:([statusMenu indexOfItem:processList] + 1)];
        [appItem release];
    }
    
    [procs release];
}

- (void)updateMenu {
    BOOL integrated = switcherUseIntegrated();
    Log(@"Updating status...");
    
    // prevent GPU from switching back after apps quit
    if (!integrated && !usingLegacy && [intelOnly state] > 0 && canPreventSwitch) {
        Log(@"Preventing switch to 330M. Setting canPreventSwitch to NO so that this doesn't get stuck in a loop, changing in 5 seconds...");
        canPreventSwitch = NO;
        [self setMode:intelOnly];
        [NSTimer scheduledTimerWithTimeInterval:5 target:self selector:@selector(shouldPreventSwitch) userInfo:nil repeats:NO];
        return;
    }
    
    // update icon and labels according to selected GPU
    NSString* cardString = integrated ? integratedString : discreteString;
    [statusItem setImage:[NSImage imageNamed:integrated ? @"intel-3.png" : @"nvidia-3.png"]];
    [currentCard setTitle:[Str(@"Card") stringByReplacingOccurrencesOfString:@"%%" withString:cardString]];
    [currentPowerSource setTitle:[NSString stringWithFormat:@"Power Source: %@", (powerSourceMonitor.currentPowerSource == psBattery) ? @"Battery" : @"AC Adaptor"]];
    
    if (integrated) Log(@"%@ in use. Sweet deal! More battery life.", integratedString);
    else Log(@"%@ in use. Bummer! No battery life for you.", discreteString);
    
    if ([prefs shouldGrowl] && canGrowl && usingIntegrated != integrated) {
        NSString *msg  = [NSString stringWithFormat:@"%@ now in use.", cardString];
        NSString *name = integrated ? @"switchedToIntegrated" : @"switchedToDiscrete";
        [GrowlApplicationBridge notifyWithTitle:@"GPU changed" description:msg notificationName:name iconData:nil priority:0 isSticky:NO clickContext:nil];
    }
    
    usingIntegrated = integrated;
    if (!integrated) [self updateProcessList];
}

- (NSDictionary *)registrationDictionaryForGrowl {
    return [NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"Growl Registration Ticket" ofType:@"growlRegDict"]];
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

- (IBAction)openApplicationURL:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://codykrieger.com/gfxCardStatus/"]];
}

- (void)shouldPreventSwitch {
    Log(@"Can prevent switching again.");
    canPreventSwitch = YES;
}

- (NSMenuItem *)senderForMode:(switcherMode)mode {
    // convert switcher mode to a menu item (consumed by setMode:)
    
    switch (mode) {
        case modeForceIntel:
            return intelOnly;
        case modeForceNvidia:
            return nvidiaOnly;
        case modeDynamicSwitching:
            return dynamicSwitching;
        case modeToggleGPU:
            // warnings suck. all your base are belong to us.
            break;
    }
    
    return dynamicSwitching;
}

- (void)powerSourceChanged:(PowerSource)powerSource {
    if (powerSource == lastPowerSource) {
        Log(@"Power source unchanged, false alarm (maybe a wake from sleep?)");
        return;
    }
    
    Log(@"Power source changed: %d => %d", lastPowerSource, powerSource);
    lastPowerSource = powerSource;
    
    if ([prefs shouldUsePowerSourceBasedSwitching]) {
        switcherMode newMode = [prefs modeForPowerSource:keyForPowerSource(powerSource)];
        [self setMode:[self senderForMode:newMode]];
    }
    
    [self updateMenu];
}

- (void)checkCardState {
    // it seems right after waking from sleep, locking to single GPU will fail (even if the return value is correct)
    // this is a temporary workaround to double-check the status
    
    if (!usingLegacy) {
        switcherMode currentMode = switcherGetMode(); // actual current mode
        NSMenuItem *activeCard = [self senderForMode:currentMode]; // corresponding menu item
        
        // check if its consistent with menu state
        if ([activeCard state] != NSOnState) {
            Log(@"Inconsistent menu state and active card, forcing retry");
            lastPowerSource = -1; // set to uninitialized
            
            // set menu item to reflect actual status
            [intelOnly setState:NSOffState];
            [nvidiaOnly setState:NSOffState];
            [dynamicSwitching setState:NSOffState];
            [activeCard setState:NSOnState];
            
            [self powerSourceChanged:powerSourceMonitor.currentPowerSource];
            
            return;
        }
    }
}

- (IBAction)quit:(id)sender {
    [[NSApplication sharedApplication] terminate:self];
}

- (void)applicationWillTerminate:(NSNotification *)notification {
    if ([intelOnly state] > 0) {
        [prefs setLastMode:0];
    } else if ([nvidiaOnly state] > 0) {
        [prefs setLastMode:1];
    } else if ([dynamicSwitching state] > 0) {
        [prefs setLastMode:2];
    }
}

- (void)dealloc {
    procFree(); // Free processes listing buffers
    switcherClose(); // Close driver
    
    [statusItem release];
    [super dealloc];
}

@end
