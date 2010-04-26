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
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	if ( ! [defaults boolForKey:@"hasRun"]) {
		[defaults setBool:YES forKey:@"hasRun"];
		[defaults setInteger:35 forKey:@"updateInterval"];
		[defaults setBool:YES forKey:@"checkForUpdatesOnLaunch"];
		[defaults setBool:YES forKey:@"useGrowl"];
	}
	
	if ([defaults boolForKey:@"checkForUpdatesOnLaunch"]) {
		[updater checkForUpdatesInBackground];
	}
	
	//if ([defaults integerForKey:@"updateInterval"] > 0) {
//		intervalTimer = [NSTimer scheduledTimerWithTimeInterval:[defaults integerForKey:@"updateInterval"] target:self selector:@selector(updateMenuBarIcon) userInfo:nil repeats:YES];
//	}
	
	[preferencesWindow setReleasedWhenClosed:NO];
	
	//timerHit = -1;
	
	statusItem = [[[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength] retain];
	[statusItem setMenu:statusMenu];
	[statusItem setHighlightMode:YES];
	
	//NSLog(@"%@", [[NSWorkspace sharedWorkspace] launchedApplications]);
	NSNotificationCenter *workspaceNotifications = [[NSWorkspace sharedWorkspace] notificationCenter];
	NSNotificationCenter *defaultNotifications = [NSNotificationCenter defaultCenter];
	
	[workspaceNotifications addObserver:self selector:@selector(handleNotification:) 
								   name:NSWorkspaceDidLaunchApplicationNotification object:nil];
	[workspaceNotifications addObserver:self selector:@selector(handleNotification:) 
								   name:NSWorkspaceDidTerminateApplicationNotification object:nil];
	[defaultNotifications addObserver:self selector:@selector(handleNotification:)
								   name:NSApplicationDidChangeScreenParametersNotification object:nil];
	
	[self performSelector:@selector(updateMenuBarIcon)];
}

- (IBAction)updateStatus:(id)sender {
	[self performSelector:@selector(updateMenuBarIcon)];
}

- (void)handleNotification:(NSNotification *)notification {
	NSLog(@"The following notification has been triggered:\n%@", notification);
	
	//timerHit = 0;
	[self performSelector:@selector(updateMenuBarIcon)];
}

- (void)updateMenuBarIcon {
	//if (timerHit >= 9) {
//		timerHit = -1;
//		[notificationTimer invalidate];
//	} else if (timerHit > -1) {
//		notificationTimer = [NSTimer scheduledTimerWithTimeInterval:2.5 target:self selector:@selector(updateMenuBarIcon) userInfo:nil repeats:NO];
//		timerHit++;
//	}
	
	NSLog(@"update called");
	if ([systemProfiler isUsingIntegratedGraphics]) {
		[statusItem setImage:[NSImage imageNamed:@"intel-3.png"]];
		[currentCard setTitle:@"Card: Intel HD Graphics"];
	} else {
		[statusItem setImage:[NSImage imageNamed:@"nvidia-3.png"]];
		[currentCard setTitle:@"Card: NVIDIA GeForce GT 330M"];
	}
}

- (IBAction)openPreferences:(id)sender {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[preferencesWindow makeKeyAndOrderFront:nil];
	[updateInterval setIntValue:[defaults integerForKey:@"updateInterval"]];
	[checkForUpdatesOnLaunch setState:[defaults integerForKey:@"checkForUpdatesOnLaunch"]];
}

- (IBAction)savePreferences:(id)sender {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults setInteger:[updateInterval intValue] forKey:@"updateInterval"];
	[defaults setInteger:[checkForUpdatesOnLaunch state] forKey:@"checkForUpdatesOnLaunch"];
	
	//[intervalTimer invalidate];
//	if ([updateInterval intValue] > 0) {
//		intervalTimer = [NSTimer scheduledTimerWithTimeInterval:[updateInterval intValue] target:self selector:@selector(updateMenuBarIcon) userInfo:nil repeats:YES];
//	}
	
	[preferencesWindow close];
}

- (IBAction)openApplicationURL:(id)sender {
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://codykrieger.com/gfxCardStatus/"]];
}

- (IBAction)quit:(id)sender {
	[[NSApplication sharedApplication] terminate:self];
}

@end
