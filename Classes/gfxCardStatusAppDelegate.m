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
        GTMLoggerError(@"Can't open connection to AppleGraphicsControl.");
        
        [GSNotifier showUnsupportedMachineMessage];
        [menuController quit:self];
    }
    
    NSArray *gpuNames = [GSGPU getGPUNames];
    GTMLoggerInfo(@"GPUs present: %@", gpuNames);
    
    [GSGPU registerForGPUChangeNotifications:self];
    
    if ([GSGPU isLegacyMachine]) {
        // do stuff
    }
    
    [menuController setupMenu];
    
    if (![prefs boolForKey:kHasSeenOneTimeNotificationKey]) {
        [GSNotifier showOneTimeNotification];
        [prefs setBool:YES forKey:kHasSeenOneTimeNotificationKey];
    }
    
    // set up growl notifications regardless of whether or not we're supposed to growl
    [GrowlApplicationBridge setGrowlDelegate:self];
}

#pragma mark - GSGPUDelegate protocol

- (void)gpuChangedTo:(GSGPUType)gpu
{
    
}

- (void)applicationKindOfDidFinishLaunching:(NSNotification *)aNotification {
    prefs = [PrefsController sharedInstance];
    state = [GSState sharedInstance];
    [state setDelegate:self];
    
    // initialize driver and process listing
    if (![GSMux switcherOpen]) GTMLoggerDebug(@"Can't open driver");
    
    // set up growl notifications regardless of whether or not we're supposed to growl
    [GrowlApplicationBridge setGrowlDelegate:self];
    
    // check for updates if user has them enabled
    // FIXME: hook up pref directly to updater.automaticallyChecksForUpdates
    if ([prefs shouldCheckForUpdatesOnStartup])
        [updater checkForUpdatesInBackground];
    
    // status item
//    [statusMenu setDelegate:self];
    statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    [statusItem setMenu:statusMenu];
    [statusItem setHighlightMode:YES];
    
    // v2.0 alert
    if (![prefs boolForKey:@"hasSeenVersionTwoMessage"]) {
        
        
        [prefs setBool:YES forKey:@"hasSeenVersionTwoMessage"];
    }
    
    // notifications and kvo
    NSNotificationCenter *notificationCenter = [[NSWorkspace sharedWorkspace] notificationCenter];
    [notificationCenter addObserver:self selector:@selector(handleWake:)
                                 name:NSWorkspaceDidWakeNotification object:nil];
    
    [prefs addObserver:self forKeyPath:@"prefs.shouldUseSmartMenuBarIcons" options:NSKeyValueObservingOptionNew context:nil];
    
    // identify current gpu and set up menus accordingly
    NSDictionary *profile = nil; //[GSProcess getGraphicsProfile];
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
    
    GTMLoggerDebug(@"Fetched machine profile: %@", profile);
    
    [switchGPUs setHidden:![state usingLegacy]];
    [integratedOnly setHidden:[state usingLegacy]];
    [discreteOnly setHidden:[state usingLegacy]];
    [dynamicSwitching setHidden:[state usingLegacy]];
    
    if (![state usingLegacy]) {
        BOOL dynamic = [GSMux isUsingDynamicSwitching];
        [integratedOnly setState:(!dynamic && [state usingIntegrated]) ? NSOnState : NSOffState];
        [discreteOnly setState:(!dynamic && ![state usingIntegrated]) ? NSOnState : NSOffState];
        [dynamicSwitching setState:dynamic ? NSOnState : NSOffState];
    }
    
    [self updateMenu];
    
    // only resture last mode if preference is set, and we're NOT using power source-based switching
    if ([prefs shouldRestoreStateOnStartup] && ![prefs shouldUsePowerSourceBasedSwitching] && ![state usingLegacy]) {
        GTMLoggerInfo(@"Restoring last used mode (%i)...", [prefs shouldRestoreToMode]);
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
        
        [menuController setMode:modeItem];
    }
    
//    powerSourceMonitor = [[PowerSourceMonitor alloc] initWithDelegate:self];
//    lastPowerSource = -1; // uninitialized
    
    // check current power source and load preference for it
//    [self powerSourceChanged:powerSourceMonitor.currentPowerSource];
}

- (NSDictionary *)registrationDictionaryForGrowl {
    return [NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"Growl Registration Ticket" ofType:@"growlRegDict"]];
}

- (void)gpuChangedTo:(GPUType)gpu from:(GPUType)from {
    [self updateMenu];
    
    if (gpu != from) {
        NSString *cardString = [state usingIntegrated] ? [state integratedString] : [state discreteString];
        NSString *msg  = [NSString stringWithFormat:Str(@"GrowlSwitch"), cardString];
        NSString *name = [state usingIntegrated] ? @"switchedToIntegrated" : @"switchedToDiscrete";
        [GrowlApplicationBridge notifyWithTitle:Str(@"GrowlGPUChanged") description:msg notificationName:name iconData:nil priority:0 isSticky:NO clickContext:nil];
    }
    
    // verify state
    [self performSelector:@selector(checkCardState) withObject:nil afterDelay:2.0];
}

- (void)handleWake:(NSNotification *)notification {
    GTMLoggerDebug(@"Wake notification! %@", notification);
    [self performSelector:@selector(delayedPowerSourceCheck) withObject:nil afterDelay:7.0];
}

- (void)delayedPowerSourceCheck {
//    [self powerSourceChanged:powerSourceMonitor.currentPowerSource];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString:@"prefs.shouldUseSmartMenuBarIcons"]) {
        [self updateMenu];
    }
}

#pragma mark - Menu Actions

- (void)menuNeedsUpdate:(NSMenu *)menu {
    //[self updateMenu];
    [self updateProcessList];
}

- (void)menuWillOpen:(NSMenu *)menu {
    // white image when menu is open
    if ([prefs shouldUseImageIcons]) {
        [statusItem setImage:[NSImage imageNamed:[[[statusItem image] name] stringByAppendingString:@"-white.png"]]];
    }
}

- (void)menuDidClose:(NSMenu *)menu {
    // black image when menu is closed
    if ([prefs shouldUseImageIcons]) {
        [statusItem setImage:[NSImage imageNamed:[[[statusItem image] name] stringByReplacingOccurrencesOfString:@"-white" withString:@".png"]]];
    }
}

- (void)updateMenu {
    GTMLoggerDebug(@"Updating status...");
    
    // get updated GPU string
    NSString *cardString = [state usingIntegrated] ? [state integratedString] : [state discreteString];
    
    // set menu bar icon
    if ([prefs shouldUseImageIcons]) {
        [statusItem setImage:[NSImage imageNamed:[state usingIntegrated] ? @"integrated.png" : @"discrete.png"]];
    } else {
        // grab first character of GPU string for the menu bar icon
        unichar firstLetter;
        
        if ([state usingLegacy] || ![prefs shouldUseSmartMenuBarIcons]) {
            firstLetter = [state usingIntegrated] ? 'i' : 'd';
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
        NSDictionary *attributes = [[NSDictionary alloc] initWithObjectsAndKeys:
                                     boldItalic, NSFontAttributeName, 
                                     [NSNumber numberWithDouble:2.0], NSBaselineOffsetAttributeName, nil];
        NSAttributedString *title = [[NSAttributedString alloc] 
                                      initWithString:letter
                                      attributes: attributes];
        
        // set menu bar text "icon"
        [statusItem setAttributedTitle:title];
    }    
    
    [currentCard setTitle:[Str(@"Card") stringByReplacingOccurrencesOfString:@"%%" withString:cardString]];
    
    if ([state usingIntegrated]) GTMLoggerInfo(@"%@ in use. Sweet deal! More battery life.", [state integratedString]);
    else GTMLoggerInfo(@"%@ in use. Bummer! Less battery life for you.", [state discreteString]);
    
    if (![state usingIntegrated]) [self updateProcessList];
}

- (void)updateProcessList {
    for (NSMenuItem *mi in [statusMenu itemArray]) {
        if ([mi indentationLevel] > 0 && ![mi isEqual:processList]) [statusMenu removeItem:mi];
    }
    
    // if we're on Integrated (or using a 9400M/9600M GT model), no need to display/update the list
    BOOL procList = ![state usingIntegrated] && ![state usingLegacy];
    [processList setHidden:!procList];
    [processesSeparator setHidden:!procList];
    [dependentProcesses setHidden:!procList];
    if (!procList) return;
    
    GTMLoggerDebug(@"Updating process list...");
    
    NSArray *processes = [GSProcess getTaskList];
    
    [processList setHidden:([processes count] > 0)];
    
    for (NSDictionary *dict in processes) {
        NSString *taskName = [dict objectForKey:kTaskItemName];
        NSString *pid = [dict objectForKey:kTaskItemPID];
        NSString *title = [NSString stringWithString:taskName];
        if (![pid isEqualToString:@""]) title = [title stringByAppendingFormat:@", PID: %@", pid];
        
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:title action:nil keyEquivalent:@""];
        [item setIndentationLevel:1];
        [statusMenu insertItem:item atIndex:([statusMenu indexOfItem:processList] + 1)];
    }
}

#pragma mark - Helpers

- (NSMenuItem *)senderForMode:(SwitcherMode)mode {
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
    
    SwitcherMode currentMode = modeDynamicSwitching; //[GSProcess switcherGetMode]; // actual current mode
    NSMenuItem *activeCard = [self senderForMode:currentMode]; // corresponding menu item
    
    // check if we're consistent with menu state
    if ([activeCard state] != NSOnState && ![state usingLegacy]) {
        GTMLoggerDebug(@"Inconsistent menu state and active card, forcing retry");
        
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
    
//    [self powerSourceChanged:powerSourceMonitor.currentPowerSource];
}

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
//        SwitcherMode newMode = [prefs modeForPowerSource:
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
