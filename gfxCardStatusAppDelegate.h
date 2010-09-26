//
//  gfxCardStatusAppDelegate.h
//  gfxCardStatus
//
//  Created by Cody Krieger on 4/22/10.
//  Copyright 2010 Cody Krieger. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Sparkle/Sparkle.h>
#import <Sparkle/SUUpdater.h>
#import <Growl/Growl.h>

#import "PrefsController.h"
#import "PowerSourceMonitor.h"

extern BOOL canLog;
#define Log(...) ({ if (canLog) NSLog(__VA_ARGS__); })

@interface gfxCardStatusAppDelegate : NSObject <NSApplicationDelegate,GrowlApplicationBridgeDelegate,NSMenuDelegate,PowerSourceMonitorDelegate> {
    NSStatusItem *statusItem;
    
    IBOutlet SUUpdater *updater;
    IBOutlet NSMenu *statusMenu;
    
    // dynamic menu items - these change
    IBOutlet NSMenuItem *versionItem;
    IBOutlet NSMenuItem *updateItem;
    IBOutlet NSMenuItem *preferencesItem;
    IBOutlet NSMenuItem *quitItem;

    IBOutlet NSMenuItem *currentCard;
    IBOutlet NSMenuItem *currentPowerSource;
    IBOutlet NSMenuItem *switchGPUs;
    IBOutlet NSMenuItem *intelOnly;
    IBOutlet NSMenuItem *nvidiaOnly;
    IBOutlet NSMenuItem *dynamicSwitching;
    
    // process list menu items
    IBOutlet NSMenuItem *processesSeparator;
    IBOutlet NSMenuItem *dependentProcesses;
    IBOutlet NSMenuItem *processList;
    
    // about window
    IBOutlet NSWindow *aboutWindow;
    IBOutlet NSButton *aboutClose;
    
    // preferences for all!
    PrefsController *prefs;
    
    // some basic status indicator bools
    BOOL canGrowl;
    BOOL usingIntegrated;
    BOOL usingLegacy;
    
    BOOL canPreventSwitch;
    
    NSString *integratedString;
    NSString *discreteString;
    
    // power source monitor
    PowerSourceMonitor *powerSourceMonitor;
    PowerSource lastPowerSource;
}

- (void)updateMenuBarIcon;
- (void)updateProcessList;

- (IBAction)setMode:(id)sender;

- (IBAction)openPreferences:(id)sender;
- (IBAction)openAbout:(id)sender;
- (IBAction)closeAbout:(id)sender;
- (IBAction)openApplicationURL:(id)sender;
- (IBAction)quit:(id)sender;

- (void)shouldPreventSwitch;

@end
