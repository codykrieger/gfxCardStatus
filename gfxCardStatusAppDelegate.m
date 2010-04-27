//
//  gfxCardStatusAppDelegate.m
//  gfxCardStatus
//
//  Created by Cody Krieger on 4/22/10.
//  Copyright 2010 Cody Krieger. All rights reserved.
//

#import "gfxCardStatusAppDelegate.h"
#import "systemProfiler.h"
#import "JSON.h"

@implementation gfxCardStatusAppDelegate

@synthesize window;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	// check for first run and set up defaults
	defaults = [NSUserDefaults standardUserDefaults];
	if ( ! [defaults boolForKey:@"hasRun"]) {
		[defaults setBool:YES forKey:@"hasRun"];
		[defaults setBool:YES forKey:@"checkForUpdatesOnLaunch"];
		[defaults setBool:YES forKey:@"useGrowl"];
	}
	
	// added for v1.3.1
	if ( ! [defaults boolForKey:@"hasRun1.3.1"]) {
		[defaults setBool:YES forKey:@"hasRun1.3.1"];
		[defaults setBool:NO forKey:@"logToConsole"];
	}
	
	// check for updates if user has them enabled
	if ([defaults boolForKey:@"checkForUpdatesOnLaunch"]) {
		[updater checkForUpdatesInBackground];
	}
	
	// set up growl if necessary
	if ([defaults boolForKey:@"useGrowl"]) {
		[GrowlApplicationBridge setGrowlDelegate:self];
	}
	
	// set preferences window...preferences
	[preferencesWindow setLevel:NSModalPanelWindowLevel];
	
	// set up status item
	statusItem = [[[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength] retain];
	[statusItem setMenu:statusMenu];
	[statusItem setHighlightMode:YES];
	
	// stick cfbundleversion into the topmost menu item
	NSString *version = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
	[versionItem setTitle:[NSString stringWithFormat: @"gfxCardStatus, v%@", version]];
	
	//NSNotificationCenter *workspaceNotifications = [[NSWorkspace sharedWorkspace] notificationCenter];
	NSNotificationCenter *defaultNotifications = [NSNotificationCenter defaultCenter];
	
	//[workspaceNotifications addObserver:self selector:@selector(handleNotification:) 
//								   name:NSWorkspaceDidLaunchApplicationNotification object:nil];
//	[workspaceNotifications addObserver:self selector:@selector(handleNotification:) 
//								   name:NSWorkspaceDidTerminateApplicationNotification object:nil];
	[defaultNotifications addObserver:self selector:@selector(handleNotification:)
								   name:NSApplicationDidChangeScreenParametersNotification object:nil];
	
	canGrowl = NO;
	[self performSelector:@selector(updateMenuBarIcon)];
	canGrowl = YES;
}

- (IBAction)updateStatus:(id)sender {
	[self performSelector:@selector(updateMenuBarIcon)];
}

- (void)handleNotification:(NSNotification *)notification {
	if ([defaults boolForKey:@"logToConsole"])
		NSLog(@"The following notification has been triggered:\n%@", notification);
	
	[self performSelector:@selector(updateMenuBarIcon)];
}

- (void)updateMenuBarIcon {
	if ([defaults boolForKey:@"logToConsole"])
		NSLog(@"update called");
	if ([systemProfiler isUsingIntegratedGraphics]) {
		[statusItem setImage:[NSImage imageNamed:@"intel-3.png"]];
		[currentCard setTitle:@"Card: Intel® HD Graphics"];
		if ([defaults boolForKey:@"logToConsole"])
			NSLog(@"Intel® HD Graphics are in use. Sweet deal! More battery life.");
		if ([defaults boolForKey:@"useGrowl"] && canGrowl)
			[GrowlApplicationBridge notifyWithTitle:@"GPU changed" description:@"Intel® HD Graphics now in use." notificationName:@"switchedToIntel" iconData:nil priority:0 isSticky:NO clickContext:nil];
	} else {
		[statusItem setImage:[NSImage imageNamed:@"nvidia-3.png"]];
		[currentCard setTitle:@"Card: NVIDIA® GeForce GT 330M"];
		if ([defaults boolForKey:@"logToConsole"])
			NSLog(@"NVIDIA® GeForce GT 330M is in use. Bummer! No battery life for you.");
		if ([defaults boolForKey:@"useGrowl"] && canGrowl)
			[GrowlApplicationBridge notifyWithTitle:@"GPU changed" description:@"NVIDIA® GeForce GT 330M graphics now in use." notificationName:@"switchedToNvidia" iconData:nil priority:0 isSticky:NO clickContext:nil];
	}
}

- (NSDictionary *)registrationDictionaryForGrowl {
	return [NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"Growl Registration Ticket" ofType:@"growlRegDict"]];
}

- (IBAction)openPreferences:(id)sender {
	// set up values on prefs window
	[checkForUpdatesOnLaunch setState:([defaults boolForKey:@"checkForUpdatesOnLaunch"] ? 1 : 0)];
	[useGrowl setState:([defaults boolForKey:@"useGrowl"] ? 1 : 0)];
	[logToConsole setState:([defaults boolForKey:@"logToConsole"] ? 1 : 0)];
	
	// open window and force to the front
	[preferencesWindow makeKeyAndOrderFront:nil];
	[preferencesWindow orderFrontRegardless];
}

- (IBAction)savePreferences:(id)sender {
	// save values to defaults
	[defaults setBool:([checkForUpdatesOnLaunch state] > 0 ? YES : NO) forKey:@"checkForUpdatesOnLaunch"];
	[defaults setBool:([useGrowl state] > 0 ? YES : NO) forKey:@"useGrowl"];
	[defaults setBool:([logToConsole state] > 0 ? YES : NO) forKey:@"logToConsole"];
	
	[preferencesWindow close];
}

- (IBAction)openApplicationURL:(id)sender {
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://codykrieger.com/gfxCardStatus/"]];
}

- (IBAction)quit:(id)sender {
	[[NSApplication sharedApplication] terminate:self];
}

@end
