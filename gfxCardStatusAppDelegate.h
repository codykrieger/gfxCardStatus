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

@interface gfxCardStatusAppDelegate : NSObject <NSApplicationDelegate,GrowlApplicationBridgeDelegate,NSMenuDelegate> {
	NSWindow *window;
	
	IBOutlet SUUpdater *updater;
	
	NSStatusItem *statusItem;
	
	IBOutlet NSMenu *statusMenu;
	
	// dynamic menu items - these change
	IBOutlet NSMenuItem *versionItem;
	IBOutlet NSMenuItem *currentCard;
	IBOutlet NSMenuItem *currentSwitching;
	IBOutlet NSMenuItem *toggleGPUs;
	IBOutlet NSMenuItem *toggleSwitching;
	IBOutlet NSMenuItem *processesSeparator;
	IBOutlet NSMenuItem *dependentProcesses;
	IBOutlet NSMenuItem *processList;
	
	// preferences window and its controls
	IBOutlet NSWindow *preferencesWindow;
	IBOutlet NSButton *checkForUpdatesOnLaunch;
	IBOutlet NSButton *useGrowl;
	IBOutlet NSButton *logToConsole;
	
	// defaults for all!
	NSUserDefaults *defaults;
	
	// some basic status indicator bools
	BOOL canGrowl;
	BOOL usingIntel;
	BOOL alwaysIntel;
	BOOL alwaysNvidia;
}

- (IBAction)updateStatus:(id)sender;
- (IBAction)toggleGPU:(id)sender;
- (IBAction)openPreferences:(id)sender;
- (IBAction)savePreferences:(id)sender;
- (IBAction)openApplicationURL:(id)sender;
- (IBAction)quit:(id)sender;

@property (assign) IBOutlet NSWindow *window;

@end
