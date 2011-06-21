//
//  gfxCardStatusAppDelegate.m
//  gfxCardStatus
//
//  Created by Cody Krieger on 4/22/10.
//  Copyright 2010 Cody Krieger. All rights reserved.
//

#import "gfxCardStatusAppDelegate.h"
#import "SystemInfo.h"
#import "switcher.h"
#import "proc.h"
#import "NSAttributedString+Hyperlink.h"

@implementation gfxCardStatusAppDelegate

#pragma mark Initialization
#pragma mark -

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    prefs = [PrefsController sharedInstance];
    state = [SessionMagic sharedInstance];
    
    // initialize driver and process listing
    if (!switcherOpen()) DLog(@"Can't open driver");
    if (!procInit()) DLog(@"Can't obtain I/O Kit's master port");
    
    // localization
    NSString *version = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
    [versionItem setTitle:[Str(@"About") stringByReplacingOccurrencesOfString:@"%%" withString:version]];
    NSArray* localized = [[NSArray alloc] initWithObjects:updateItem, preferencesItem, quitItem, switchGPUs, integratedOnly, 
                          discreteOnly, dynamicSwitching, dependentProcesses, processList, aboutWindow, aboutClose, nil];
    for (NSButton *loc in localized) {
        [loc setTitle:Str([loc title])];
    }
    [localized release];
    
    // set up growl notifications regardless of whether or not we're supposed to growl
    [GrowlApplicationBridge setGrowlDelegate:self];
    
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
    NSDictionary *profile = [SystemInfo getGraphicsProfile];
    if ([(NSNumber *)[profile objectForKey:@"unsupported"] boolValue]) {
        [state setUsingIntegrated:NO];
        NSAlert *alert = [NSAlert alertWithMessageText:@"You are using a system that gfxCardStatus does not support. Please ensure that you are using a MacBook Pro with dual GPUs." 
                                         defaultButton:@"Oh, I see." alternateButton:nil otherButton:nil informativeTextWithFormat:@""];
        [alert runModal];
    } else {
        [state setUsingIntegrated:[(NSNumber *)[profile objectForKey:@"usingIntegrated"] boolValue]];
    }
    
    [state setIntegratedString:(NSString *)[profile objectForKey:@"integratedString"]];
    [state setDiscreteString:(NSString *)[profile objectForKey:@"discreteString"]];
    
    DLog(@"Fetched machine profile: %@", profile);
    
    [switchGPUs setHidden:![prefs usingLegacy]];
    [integratedOnly setHidden:[prefs usingLegacy]];
    [discreteOnly setHidden:[prefs usingLegacy]];
    [dynamicSwitching setHidden:[prefs usingLegacy]];
    
    if ([prefs usingLegacy]) {
    } else {
        BOOL dynamic = switcherUseDynamicSwitching();
        [integratedOnly setState:(!dynamic && [state usingIntegrated]) ? NSOnState : NSOffState];
        [discreteOnly setState:(!dynamic && ![state usingIntegrated]) ? NSOnState : NSOffState];
        [dynamicSwitching setState:dynamic ? NSOnState : NSOffState];
    }
    
    [state setCanGrowl:NO];
    [self updateMenu];
    
    // only resture last mode if preference is set, and we're NOT using power source-based switching
    if ([prefs shouldRestoreStateOnStartup] && ![prefs shouldUsePowerSourceBasedSwitching] && ![prefs usingLegacy]) {
        DLog(@"Restoring last used mode (%i)...", [prefs shouldRestoreToMode]);
        id modeItem = nil;
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
    
    [state setCanGrowl:YES];
    
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
    
    DLog(@"The following notification has been triggered:\n%@", notification);
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
    // [statusItem setImage:[NSImage imageNamed:[[[statusItem image] name] stringByAppendingString:@"-white.png"]]];
}

- (void)menuDidClose:(NSMenu *)menu {
    // black image when menu is closed
    // [statusItem setImage:[NSImage imageNamed:[[[statusItem image] name] stringByReplacingOccurrencesOfString:@"-white" withString:@".png"]]];
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
        DLog(@"Switching GPUs...");
        switcherSetMode(modeToggleGPU);
        return;
    }
    
    // current cards
    if ([sender state] == NSOnState) return;
    
    BOOL retval = NO;
    if (sender == integratedOnly) {
        DLog(@"Setting Integrated only...");
        retval = switcherSetMode(modeForceIntegrated);
    }
    if (sender == discreteOnly) { 
        DLog(@"Setting NVIDIA only...");
        retval = switcherSetMode(modeForceDiscrete);
    }
    if (sender == dynamicSwitching) {
        DLog(@"Setting dynamic switching...");
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
    DLog(@"Updating status...");
    
    // TODO - fix this, not working
    // prevent GPU from switching back after apps quit
    //    if (!integrated && ![prefs usingLegacy] && [integratedOnly state] > 0 && canPreventSwitch) {
    //        DLog(@"Preventing switch to Discrete GPU. Setting canPreventSwitch to NO so that this doesn't get stuck in a loop, changing in 5 seconds...");
    //        canPreventSwitch = NO;
    //        [self setMode:integratedOnly];
    //        [NSTimer scheduledTimerWithTimeInterval:5 target:self selector:@selector(shouldPreventSwitch) userInfo:nil repeats:NO];
    //        return;
    //    }
    
    
    // get updated GPU string
    NSString* cardString = integrated ? [state integratedString] : [state discreteString];
    
    // set menu bar icon
    // [statusItem setImage:[NSImage imageNamed:integrated ? @"integrated-3.png" : @"discrete-3.png"]];
    
    // grab first character of GPU string for the menu bar icon
    unichar firstLetter;
    if ([prefs usingLegacy]) {
        firstLetter = integrated ? 'i' : 'd';
    } else {
        firstLetter = [cardString characterAtIndex:0];
    }
    
    // format firstLetter into an NSString *
    NSString *letter = [[NSString stringWithFormat:@"%C", firstLetter] lowercaseString];
    int fontSize = ([letter isEqualToString:@"n"] || [letter isEqualToString:@"a"] ? 19 : 18);
    
    // set the correct font
    NSFontManager *fontManager = [NSFontManager sharedFontManager];
    NSFont *boldItalic = [fontManager fontWithFamily:@"Georgia"
                                              traits:NSBoldFontMask|NSItalicFontMask
                                              weight:0
                                                size:fontSize];
    
    // create NSAttributedString with font
    NSDictionary *attributes = [[[NSDictionary alloc] initWithObjectsAndKeys:
                                boldItalic, NSFontAttributeName, 
                                [NSNumber numberWithDouble:2.0], NSBaselineOffsetAttributeName, nil] autorelease];
    NSAttributedString *title = [[[NSAttributedString alloc] 
                                 initWithString:letter
                                    attributes: attributes] autorelease];
    
    // set menu bar text "icon"
    [statusItem setAttributedTitle:title];
    
    
    [currentCard setTitle:[Str(@"Card") stringByReplacingOccurrencesOfString:@"%%" withString:cardString]];
    [currentPowerSource setTitle:[Str(@"PowerSource") stringByReplacingOccurrencesOfString:@"%%" withString:(powerSourceMonitor.currentPowerSource == psBattery) ? Str(@"Battery") : Str(@"ACAdapter")]];
    
    if (integrated) DLog(@"%@ in use. Sweet deal! More battery life.", integratedString);
    else DLog(@"%@ in use. Bummer! Less battery life for you.", discreteString);
    
    if ([state canGrowl] && [state usingIntegrated] != integrated) {
        NSString *msg  = [NSString stringWithFormat:@"%@ %@", cardString, Str(@"GrowlSwitch")];
        NSString *name = integrated ? @"switchedToIntegrated" : @"switchedToDiscrete";
        [GrowlApplicationBridge notifyWithTitle:Str(@"GrowlGPUChanged") description:msg notificationName:name iconData:nil priority:0 isSticky:NO clickContext:nil];
    }
    
    [state setUsingIntegrated:integrated];
    if (!integrated) [self updateProcessList];
}

- (void)updateProcessList {
    for (NSMenuItem *mi in [statusMenu itemArray]) {
        if ([mi indentationLevel] > 0 && ![mi isEqual:processList]) [statusMenu removeItem:mi];
    }
    
    // if we're on Integrated (or using a 9400M/9600M GT model), no need to display/update the list
    BOOL procList = ![state usingIntegrated] && ![prefs usingLegacy];
    [processList setHidden:!procList];
    [processesSeparator setHidden:!procList];
    [dependentProcesses setHidden:!procList];
    if (!procList) return;
    
    DLog(@"Updating process list...");
    
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
    if (!procGet(procs)) DLog(@"Can't obtain I/O Kit's root service");
    
    [processList setHidden:([procs count] > 0 || usingExternalDisplay)];
    if ([procs count]==0) DLog(@"We're using the Discrete card, but no process requires it. An external monitor may be connected, or we may be in Discrete Only mode.");
    
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
    
    switcherMode currentMode = [SystemInfo switcherGetMode]; // actual current mode
    NSMenuItem *activeCard = [self senderForMode:currentMode]; // corresponding menu item
    
    // check if its consistent with menu state
    if ([activeCard state] != NSOnState && ![prefs usingLegacy]) {
        DLog(@"Inconsistent menu state and active card, forcing retry");
        
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
        //DLog(@"Power source unchanged, false alarm (maybe a wake from sleep?)");
        return;
    }
    
    DLog(@"Power source changed: %d => %d (%@)", lastPowerSource, powerSource, (powerSource == psBattery ? @"Battery" : @"AC Adapter"));
    lastPowerSource = powerSource;
    
    if ([prefs shouldUsePowerSourceBasedSwitching]) {
        switcherMode newMode = [prefs modeForPowerSource:[SystemInfo keyForPowerSource:powerSource]];
        
        if (![prefs usingLegacy]) {
            DLog(@"Using a newer machine, setting appropriate mode based on power source...");
            [self setMode:[self senderForMode:newMode]];
        } else {
            DLog(@"Using a legacy machine, setting appropriate mode based on power source...");
            DLog(@"usingIntegrated=%i, newMode=%i", usingIntegrated, newMode);
            if (([state usingIntegrated] && newMode == 1) || (![state usingIntegrated] && newMode == 0)) {
                [self setMode:switchGPUs];
            }
        }
    }
    
    [self updateMenu];
}

- (void)dealloc {
    procFree(); // Free processes listing buffers
    switcherClose(); // Close driver
    
    [statusItem release];
    [super dealloc];
}

@end
