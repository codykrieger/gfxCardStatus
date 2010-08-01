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

#import "PowerSourceMonitor.h"

extern BOOL canLog;
#define Log(...) ({ if (canLog) NSLog(__VA_ARGS__); })
#define Str(key) NSLocalizedString(key, key)

@interface gfxCardStatusAppDelegate : NSObject <NSApplicationDelegate,GrowlApplicationBridgeDelegate,NSMenuDelegate,NSWindowDelegate,PowerSourceMonitorDelegate> {
	NSStatusItem *statusItem;
	
	IBOutlet SUUpdater *updater;
	IBOutlet NSMenu *statusMenu;
	
	// dynamic menu items - these change
	IBOutlet NSMenuItem *versionItem;
	IBOutlet NSMenuItem *updateItem;
	IBOutlet NSMenuItem *preferencesItem;
	IBOutlet NSMenuItem *quitItem;

	IBOutlet NSMenuItem *currentPowerSource;
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
	
	// preferences window
	IBOutlet NSWindow *preferencesWindow;
	IBOutlet NSButton *checkForUpdatesOnLaunch;
	IBOutlet NSButton *useGrowl;
	IBOutlet NSButton *logToConsole;
	IBOutlet NSButton *loadAtStartup;
	IBOutlet NSButton *restoreModeAtStartup;
	IBOutlet NSButton *usePowerSourceBasedSwitching;
	IBOutlet NSSegmentedControl *gpuOnBattery;
	IBOutlet NSSegmentedControl *gpuOnAdaptor;
	IBOutlet NSButton *closePrefs;
	
	// about window
	IBOutlet NSWindow *aboutWindow;
	IBOutlet NSButton *aboutClose;
	
	// defaults for all!
	NSUserDefaults *defaults;
	
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
- (IBAction)savePreferences:(id)sender;
- (IBAction)openAbout:(id)sender;
- (IBAction)closeAbout:(id)sender;
- (IBAction)openApplicationURL:(id)sender;
- (IBAction)quit:(id)sender;

- (void)shouldLoadAtStartup:(BOOL)value;
- (void)shouldPreventSwitch;

@end
