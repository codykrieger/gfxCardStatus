//
//  gfxCardStatusAppDelegate.m
//  gfxCardStatus
//
//  Created by Cody Krieger on 4/22/10.
//  Copyright 2010 Cody Krieger. All rights reserved.
//

#import "gfxCardStatusAppDelegate.h"
#import "systemProfiler.h"
#import "switcher.h"

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
	
	[statusMenu setDelegate:self];
	
	// set up status item
	statusItem = [[[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength] retain];
	[statusItem setMenu:statusMenu];
	[statusItem setHighlightMode:YES];
	
	// stick cfbundleversion into the topmost menu item
	NSString *version = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
	[versionItem setTitle:[NSString stringWithFormat: @"About gfxCardStatus, v%@", version]];
	
	// set initial process list value
	[processList setTitle:@"None"];
	
	//NSNotificationCenter *workspaceNotifications = [[NSWorkspace sharedWorkspace] notificationCenter];
	NSNotificationCenter *defaultNotifications = [NSNotificationCenter defaultCenter];
	
	//[workspaceNotifications addObserver:self selector:@selector(handleApplicationNotification:) 
//								   name:NSWorkspaceDidLaunchApplicationNotification object:nil];
//	[workspaceNotifications addObserver:self selector:@selector(handleApplicationNotification:) 
//								   name:NSWorkspaceDidTerminateApplicationNotification object:nil];
	[defaultNotifications addObserver:self selector:@selector(handleNotification:)
								   name:NSApplicationDidChangeScreenParametersNotification object:nil];
	
	// bool to identify the current gfx card without having to parse terminal output again
	usingIntel = YES;
	
	// set 'always' bools
	alwaysIntel = NO;
	alwaysNvidia = NO;
	
	canGrowl = NO;
	[self performSelector:@selector(updateMenuBarIcon)];
	canGrowl = YES;
}

- (IBAction)updateStatus:(id)sender {
	[self performSelector:@selector(updateMenuBarIcon)];
}

- (IBAction)toggleGPU:(id)sender {
	if ([defaults boolForKey:@"logToConsole"])
		NSLog(@"Switching GPUs...");
	
	//[switcher toggleGPU];
}

- (IBAction)intelOnly:(id)sender {
	if ([defaults boolForKey:@"logToConsole"])
		NSLog(@"Setting Intel only...");
	
	NSInteger state = [intelOnly state];
	
	if (state == NSOffState) {
		[switcher forceIntel];
		
		[intelOnly setState:NSOnState];
		[nvidiaOnly setState:NSOffState];
		[dynamicSwitching setState:NSOffState];
	}
}

- (IBAction)nvidiaOnly:(id)sender {
	if ([defaults boolForKey:@"logToConsole"])
		NSLog(@"Setting NVIDIA only...");
	
	NSInteger state = [nvidiaOnly state];
	
	if (state == NSOffState) {
		[switcher forceNvidia];
		
		[intelOnly setState:NSOffState];
		[nvidiaOnly setState:NSOnState];
		[dynamicSwitching setState:NSOffState];
	}
}

- (IBAction)enableDynamicSwitching:(id)sender {
	if ([defaults boolForKey:@"logToConsole"])
		NSLog(@"Setting dynamic switching...");
	
	NSInteger state = [dynamicSwitching state];
	
	if (state == NSOffState) {
		[switcher dynamicSwitching];
		
		[intelOnly setState:NSOffState];
		[nvidiaOnly setState:NSOffState];
		[dynamicSwitching setState:NSOnState];
	}
}

- (void)handleNotification:(NSNotification *)notification {
	if ([defaults boolForKey:@"logToConsole"])
		NSLog(@"The following notification has been triggered:\n%@", notification);
	
	[self performSelector:@selector(updateMenuBarIcon)];
}

- (void)menuNeedsUpdate:(NSMenu *)menu {
	[self performSelector:@selector(updateMenuBarIcon)];
	[self performSelector:@selector(updateProcessList)];
}

- (void)setDependencyListVisibility:(NSNumber *)visible {
	[processList setHidden:![visible boolValue]];
	[processesSeparator setHidden:![visible boolValue]];
	[dependentProcesses setHidden:![visible boolValue]];
}

- (void)updateProcessList {
	NSMutableArray *itemsToRemove = [[NSMutableArray alloc] init];
	
	for (NSMenuItem *mi in [statusMenu itemArray]) {
		if ([mi indentationLevel] > 0 && ![mi isEqual:processList]) {
			[itemsToRemove addObject:mi];
		}
	}
	
	for (NSMenuItem *mi in itemsToRemove) {
		[statusMenu removeItem:mi];
	}
	
	if ([defaults boolForKey:@"logToConsole"])
		NSLog(@"Updating process list...");
	
	// if we're on intel, no need to update the list
	if (!usingIntel) {
		// reset and show process list
		[self performSelector:@selector(setDependencyListVisibility:) withObject:[NSNumber numberWithBool:YES]];
		[processList setTitle:@"None"];
		
		NSString *cmd = @"/bin/ps cx -o \"pid command\" | /usr/bin/egrep $(echo ${$(/usr/sbin/ioreg -l | /usr/bin/grep task-list | /usr/bin/sed -e 's/(//' | /usr/bin/sed -e 's/)//' | /usr/bin/awk ' { print $6 }')//','/'|'})";
		
		NSTask *task = [[NSTask alloc] init];
		[task setLaunchPath:@"/bin/zsh"];
		[task setArguments:[NSArray arrayWithObjects:@"-c", cmd, nil]];
		
		NSPipe *pipe = [NSPipe pipe];
		[task setStandardOutput:pipe];
		NSFileHandle *file = [pipe fileHandleForReading];
		
		[task launch];
		[task waitUntilExit];
		
		NSData *data = [file readDataToEndOfFile];
		NSString *output = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
		
		if ([output hasPrefix:@"Usage:"]) {
			
			if ([defaults boolForKey:@"logToConsole"])
				NSLog(@"Something's up...we're using the NVIDIA® card, but there are no processes in the task-list.");
			
		} else {
			
			output = [output stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
			if ([output length] == 0) {
				
				if ([defaults boolForKey:@"logToConsole"])
					NSLog(@"Something's up...we're using the NVIDIA® card, and there are processes in the task-list, but there is no output.");
				
			} else {
				// everything's fine, parse output and unhide menu items
				
				// external display, if connected
				if ([[NSScreen screens] count] > 1) {
					NSMenuItem *externalDisplay = [[NSMenuItem alloc] initWithTitle:@"External Display" action:nil keyEquivalent:@""];
					[externalDisplay setIndentationLevel:1];
					[statusMenu insertItem:externalDisplay atIndex:([statusMenu indexOfItem:processList] + 1)];
				}
				
				NSArray *array = [output componentsSeparatedByString:@"\n"];
				for (NSString *obj in array) {
					NSArray *processInfo = [obj componentsSeparatedByString:@" "];
					NSMutableString *appName = [[NSMutableString alloc] initWithString:@""];
					if ([processInfo count] > 1) {
						
						if ([processInfo count] >= 3) {
							BOOL hitProcessId = NO;
							for (NSString *s in processInfo) {
								if ([s intValue] > 0 && !hitProcessId) {
									hitProcessId = YES;
									continue;
								}
								
								if (hitProcessId)
									[appName appendFormat:@"%@ ", s];
							}
						} else {
							[appName appendFormat:@"%@", [processInfo objectAtIndex:1]];
						}
						
						[processList setHidden:YES];
						
						NSMenuItem *newItem = [[NSMenuItem alloc] initWithTitle:appName action:nil keyEquivalent:@""];
						[newItem setIndentationLevel:1];
						[statusMenu insertItem:newItem atIndex:([statusMenu indexOfItem:processList] + 1)];
					}
					[appName release];
				}
			}
		}
	} else {
		[self performSelector:@selector(setDependencyListVisibility:) withObject:[NSNumber numberWithBool:NO]];
	}

}

- (void)updateMenuBarIcon {
	if ([defaults boolForKey:@"logToConsole"])
		NSLog(@"Updating status...");
	if ([systemProfiler isUsingIntegratedGraphics]) {
		[statusItem setImage:[NSImage imageNamed:@"intel-3.png"]];
		[currentCard setTitle:@"Card: Intel® HD Graphics"];
		if ([defaults boolForKey:@"logToConsole"])
			NSLog(@"Intel® HD Graphics are in use. Sweet deal! More battery life.");
		if ([defaults boolForKey:@"useGrowl"] && canGrowl && !usingIntel)
			[GrowlApplicationBridge notifyWithTitle:@"GPU changed" description:@"Intel® HD Graphics now in use." notificationName:@"switchedToIntel" iconData:nil priority:0 isSticky:NO clickContext:nil];
		usingIntel = YES;
		[processList setTitle:@"None"];
	} else {
		[statusItem setImage:[NSImage imageNamed:@"nvidia-3.png"]];
		[currentCard setTitle:@"Card: NVIDIA® GeForce GT 330M"];
		if ([defaults boolForKey:@"logToConsole"])
			NSLog(@"NVIDIA® GeForce GT 330M is in use. Bummer! No battery life for you.");
		if ([defaults boolForKey:@"useGrowl"] && canGrowl && usingIntel)
			[GrowlApplicationBridge notifyWithTitle:@"GPU changed" description:@"NVIDIA® GeForce GT 330M graphics now in use." notificationName:@"switchedToNvidia" iconData:nil priority:0 isSticky:NO clickContext:nil];
		usingIntel = NO;
		[self performSelector:@selector(updateProcessList)];
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

- (IBAction)openAbout:(id)sender {
	// open window and force to the front
	[aboutWindow makeKeyAndOrderFront:nil];
	[aboutWindow orderFrontRegardless];
	[aboutWindow center];
}

- (IBAction)closeAbout:(id)sender {
	[aboutWindow close];
}

- (IBAction)openApplicationURL:(id)sender {
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://codykrieger.com/gfxCardStatus/"]];
}

+ (bool)canLogToConsole {
	NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
	if ([userDefaults boolForKey:@"logToConsole"])
		return true;
	else
		return false;
}

- (IBAction)quit:(id)sender {
	[[NSApplication sharedApplication] terminate:self];
}

@end
