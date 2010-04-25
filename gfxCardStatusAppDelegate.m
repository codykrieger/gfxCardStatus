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
#import "updateManager.h"

@implementation gfxCardStatusAppDelegate

@synthesize window;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	timerHit = -1;
	
	statusItem = [[[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength] retain];
	[statusItem setMenu:statusMenu];
	//[statusItem setTitle:([systemProfiler isUsingIntegratedGraphics] ? @"gfx: intel" : @"gfx: nvidia")];
	[statusItem setHighlightMode:YES];
	
	NSLog(@"%@", [[NSWorkspace sharedWorkspace] launchedApplications]);
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
	NSLog(@"the following notification has been triggered:\n%@", notification);
	NSLog(@"the update will be performed multiple times over the next few seconds to ensure we have the correct status");
	
	timerHit = 0;
	[self performSelector:@selector(updateMenuBarIcon)];
}

- (void)updateMenuBarIcon {
	if (timerHit >= 9) {
		timerHit = -1;
		[timer invalidate];
	} else if (timerHit > -1) {
		timer = [NSTimer scheduledTimerWithTimeInterval:2.5 target:self selector:@selector(updateMenuBarIcon) userInfo:nil repeats:NO];
		timerHit++;
	}
	
	NSLog(@"update called");
	//[statusItem setTitle:([systemProfiler isUsingIntegratedGraphics] ? @"gfx: intel" : @"gfx: nvidia")];
	if ([systemProfiler isUsingIntegratedGraphics]) {
		[statusItem setImage:[NSImage imageNamed:@"intel-3.png"]];
		[currentCard setTitle:@"Card: Intel HD Graphics"];
	} else {
		[statusItem setImage:[NSImage imageNamed:@"nvidia-3.png"]];
		[currentCard setTitle:@"Card: NVIDIA GeForce GT 330M"];
	}
}

- (IBAction)quit:(id)sender {
	[[NSApplication sharedApplication] terminate:self];
}

- (IBAction)checkForApplicationUpdate:(id)sender {
	[self performSelectorInBackground:@selector(checkForUpdate) withObject:nil];
}

- (void)checkForUpdate {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	//[self performSelectorOnMainThread:@selector(finishedCheckForUpdate:) withObject:[updateManager checkForUpdate] waitUntilDone:YES];
	[updateManager update];
	
	[pool release];
}

- (void)finishedCheckForUpdate:(NSDictionary *)results {
	NSLog(@"%@", results);
}

@end
