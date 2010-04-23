//
//  gfxCardStatusAppDelegate.m
//  gfxCardStatus
//
//  Created by Cody Krieger on 4/22/10.
//  Copyright 2010 Cody Krieger. All rights reserved.
//

#import "gfxCardStatusAppDelegate.h"
#import "systemProfiler.h"

@implementation gfxCardStatusAppDelegate

@synthesize window;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	timerHit = -1;
	
	statusItem = [[[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength] retain];
	[statusItem setMenu:statusMenu];
	[statusItem setTitle:([systemProfiler isUsingIntegratedGraphics] ? @"gfx: intel" : @"gfx: nvidia")];
	[statusItem setHighlightMode:YES];
	
	NSLog(@"%@", [[NSWorkspace sharedWorkspace] launchedApplications]);
	NSNotificationCenter *workspaceNotifications = [[NSWorkspace sharedWorkspace] notificationCenter];
	[workspaceNotifications addObserver:self selector:@selector(handleNotification:) 
								   name:NSWorkspaceDidLaunchApplicationNotification object:nil];
	[workspaceNotifications addObserver:self selector:@selector(handleNotification:) 
								   name:NSWorkspaceDidTerminateApplicationNotification object:nil];
	//[workspaceNotifications addObserver:self selector:@selector(handleNotification:) 
//								   name:NSWorkspaceDidUnhideApplicationNotification object:nil];
//	[workspaceNotifications addObserver:self selector:@selector(handleNotification:) 
//								   name:NSWorkspaceDidHideApplicationNotification object:nil];
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
	if (timerHit >= 7) {
		timerHit = -1;
		[timer invalidate];
	} else if (timerHit > -1) {
		timer = [NSTimer scheduledTimerWithTimeInterval:2 target:self selector:@selector(updateMenuBarIcon) userInfo:nil repeats:NO];
		timerHit++;
	}
	
	NSLog(@"update called");
	[statusItem setTitle:([systemProfiler isUsingIntegratedGraphics] ? @"gfx: intel" : @"gfx: nvidia")];
}

- (IBAction)quit:(id)sender {
	[[NSApplication sharedApplication] terminate:self];
}

@end
