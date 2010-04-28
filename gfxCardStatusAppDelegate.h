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

@interface gfxCardStatusAppDelegate : NSObject <NSApplicationDelegate,GrowlApplicationBridgeDelegate> {
	NSWindow *window;
	
	IBOutlet SUUpdater *updater;
	
	NSStatusItem *statusItem;
	
	IBOutlet NSMenu *statusMenu;
	IBOutlet NSMenuItem *currentCard;
	IBOutlet NSMenuItem *versionItem;
	IBOutlet NSMenuItem *processesSeparator;
	IBOutlet NSMenuItem *dependentProcesses;
	IBOutlet NSMenuItem *processList;
	
	IBOutlet NSWindow *preferencesWindow;
	IBOutlet NSButton *checkForUpdatesOnLaunch;
	IBOutlet NSButton *useGrowl;
	IBOutlet NSButton *logToConsole;
	
	NSUserDefaults *defaults;
	
	BOOL canGrowl;
	BOOL usingIntel;
}

- (IBAction)updateStatus:(id)sender;
- (IBAction)openPreferences:(id)sender;
- (IBAction)savePreferences:(id)sender;
- (IBAction)openApplicationURL:(id)sender;
- (IBAction)quit:(id)sender;

@property (assign) IBOutlet NSWindow *window;

@end
