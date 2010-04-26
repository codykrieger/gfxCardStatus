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

@interface gfxCardStatusAppDelegate : NSObject <NSApplicationDelegate> {
	NSWindow *window;
	
	IBOutlet SUUpdater *updater;
	
	IBOutlet NSMenu *statusMenu;
	IBOutlet NSMenuItem *currentCard;
	IBOutlet NSMenuItem *versionItem;
	NSStatusItem *statusItem;
	
	IBOutlet NSWindow *preferencesWindow;
	IBOutlet NSTextField *updateInterval;
	IBOutlet NSButton *checkForUpdatesOnLaunch;
	IBOutlet NSButton *useGrowl;
	
	NSTimer *notificationTimer;
	int timerHit;
	
	NSTimer *intervalTimer;
}

- (IBAction)updateStatus:(id)sender;
- (IBAction)openPreferences:(id)sender;
- (IBAction)savePreferences:(id)sender;
- (IBAction)openApplicationURL:(id)sender;
- (IBAction)quit:(id)sender;

@property (assign) IBOutlet NSWindow *window;

@end
