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
	
	// added for v1.7...not used yet
	if ( ! [defaults integerForKey:@"hasRun1.7"]) {
		[defaults setBool:YES forKey:@"hasRun1.7"];
		[defaults setBool:YES forKey:@"loadAtStartup"];
		//[self shouldLoadAtStartup:YES];
		[defaults setInteger:3 forKey:@"lastGPUSetting"];
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
	
	NSNotificationCenter *defaultNotifications = [NSNotificationCenter defaultCenter];
	[defaultNotifications addObserver:self selector:@selector(handleChangeScreenParametersNotification:)
								   name:NSApplicationDidChangeScreenParametersNotification object:nil];
	
	// bool to identify the current gfx card without having to parse terminal output again
	usingIntegrated = YES;
	
	// set 'always' bools
	alwaysIntel = NO;
	alwaysNvidia = NO;
	
	usingLate08Or09 = NO;
	integratedString = @"Intel® HD Graphics";
	discreteString = @"NVIDIA® GeForce GT 330M";
	
	canGrowl = NO;
	[self performSelector:@selector(updateMenuBarIcon)];
	canGrowl = YES;
}

- (IBAction)updateStatus:(id)sender {
	[self performSelector:@selector(updateMenuBarIcon)];
}

- (IBAction)toggleGPU:(id)sender {
	if ([gfxCardStatusAppDelegate canLogToConsole])
		NSLog(@"Switching GPUs...");
	
	[switcher toggleGPU];
}

- (IBAction)intelOnly:(id)sender {
	if ([gfxCardStatusAppDelegate canLogToConsole])
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
	if ([gfxCardStatusAppDelegate canLogToConsole])
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
	if ([gfxCardStatusAppDelegate canLogToConsole])
		NSLog(@"Setting dynamic switching...");
	
	NSInteger state = [dynamicSwitching state];
	
	if (state == NSOffState) {
		[switcher dynamicSwitching];
		
		[intelOnly setState:NSOffState];
		[nvidiaOnly setState:NSOffState];
		[dynamicSwitching setState:NSOnState];
	}
}

- (void)handleChangeScreenParametersNotification:(NSNotification *)notification {
	if ([gfxCardStatusAppDelegate canLogToConsole])
		NSLog(@"The following notification has been triggered:\n%@", notification);
	
	[self performSelector:@selector(updateMenuBarIcon)];
}

- (void)menuNeedsUpdate:(NSMenu *)menu {
	//[self performSelector:@selector(updateMenuBarIcon)];
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
	
	// if we're on intel (or using a 9400M/9600M GT model), no need to update the list
	if (!usingIntegrated && !usingLate08Or09) {
		if ([gfxCardStatusAppDelegate canLogToConsole])
			NSLog(@"Updating process list...");
		
		// reset and show process list
		[self performSelector:@selector(setDependencyListVisibility:) withObject:[NSNumber numberWithBool:YES]];
		[processList setTitle:@"None"];
		
		NSString *cmd = @"/bin/ps cx -o \"pid command\" | /usr/bin/egrep ${$(/usr/sbin/ioreg -n AppleGraphicsControl | /usr/bin/grep task-list | /usr/bin/sed -E 's/(.*\\(|\\).*)//g')//','/'|'}";
		
		NSTask *task = [[NSTask alloc] init];
		[task setLaunchPath:@"/bin/zsh"];
		[task setArguments:[NSArray arrayWithObjects:@"-c", cmd, nil]];
		
		NSPipe *pipe = [NSPipe pipe];
		[task setStandardOutput:pipe];
		
		NSFileHandle *file = [pipe fileHandleForReading];
		
		[task launch];
		[task waitUntilExit];
		NSData *data = [file readDataToEndOfFile];
		[task release];
		
		NSString *output = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
		
		if ([output hasPrefix:@"Usage:"]) {
			
			if ([gfxCardStatusAppDelegate canLogToConsole])
				NSLog(@"Something's up...we're using the NVIDIA® card, but there are no processes in the task-list.");
			
		} else {
			
			output = [output stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
			if ([output length] == 0) {
				
				if ([gfxCardStatusAppDelegate canLogToConsole])
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
						[newItem release];
					}
					[appName release];
				}
			}
		}
	} else {
		[self performSelector:@selector(setDependencyListVisibility:) withObject:[NSNumber numberWithBool:NO]];
	}
	
	[itemsToRemove release];
}

- (void)updateMenuBarIcon {
	if ([gfxCardStatusAppDelegate canLogToConsole])
		NSLog(@"Updating status...");
	if ([systemProfiler isUsingIntegratedGraphics:self]) {
		[statusItem setImage:[NSImage imageNamed:@"intel-3.png"]];
		[currentCard setTitle:[NSString stringWithFormat:@"Card: %@", integratedString]];
		if ([gfxCardStatusAppDelegate canLogToConsole])
			NSLog(@"%@ in use. Sweet deal! More battery life.", integratedString);
		if ([defaults boolForKey:@"useGrowl"] && canGrowl && !usingIntegrated)
			[GrowlApplicationBridge notifyWithTitle:@"GPU changed" description:[NSString stringWithFormat:@"%@ now in use.", integratedString] notificationName:@"switchedToIntegrated" iconData:nil priority:0 isSticky:NO clickContext:nil];
		usingIntegrated = YES;
	} else {
		// ensure correct GPU is in use if intel only mode is in use
		if ([intelOnly state] > 0) {
			if ([gfxCardStatusAppDelegate canLogToConsole])
				NSLog(@"Bad OS X! It switched back to the 330M without our permission. Switching back...");
			[switcher forceIntel];
			return;
		}
		
		[statusItem setImage:[NSImage imageNamed:@"nvidia-3.png"]];
		[currentCard setTitle:[NSString stringWithFormat:@"Card: %@", discreteString]];
		if ([gfxCardStatusAppDelegate canLogToConsole])
			NSLog(@"%@ in use. Bummer! No battery life for you.", discreteString);
		if ([defaults boolForKey:@"useGrowl"] && canGrowl && usingIntegrated)
			[GrowlApplicationBridge notifyWithTitle:@"GPU changed" description:[NSString stringWithFormat:@"%@ now in use.", discreteString] notificationName:@"switchedToDiscrete" iconData:nil priority:0 isSticky:NO clickContext:nil];
		usingIntegrated = NO;
		[self performSelector:@selector(updateProcessList)];
	}
}

- (void)setUsingLate08Or09Model:(NSNumber *)value {
	usingLate08Or09 = [value boolValue];
	[self performSelector:@selector(setDependencyListVisibility:) withObject:[NSNumber numberWithBool:![value boolValue]]];
	[toggleGPUs setHidden:![value boolValue]];
	[intelOnly setHidden:[value boolValue]];
	[nvidiaOnly setHidden:[value boolValue]];
	[dynamicSwitching setHidden:[value boolValue]];
	
	if ([value boolValue]) {
		integratedString = @"NVIDIA® GeForce 9400M";
		discreteString = @"NVIDIA® GeForce 9600M GT";
	} else {
		integratedString = @"Intel® HD Graphics";
		discreteString = @"NVIDIA® GeForce GT 330M";
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
	[loadAtStartup setState:([defaults boolForKey:@"loadAtStartup"] ? 1 : 0)];
	
	// open window and force to the front
	[preferencesWindow makeKeyAndOrderFront:nil];
	[preferencesWindow orderFrontRegardless];
	[preferencesWindow center];
}

- (IBAction)savePreferences:(id)sender {
	// save values to defaults
	[defaults setBool:([checkForUpdatesOnLaunch state] > 0 ? YES : NO) forKey:@"checkForUpdatesOnLaunch"];
	[defaults setBool:([useGrowl state] > 0 ? YES : NO) forKey:@"useGrowl"];
	[defaults setBool:([logToConsole state] > 0 ? YES : NO) forKey:@"logToConsole"];
	[defaults setBool:([loadAtStartup state] > 0 ? YES : NO) forKey:@"loadAtStartup"];
	
	//[self shouldLoadAtStartup:([loadAtStartup state] > 0 ? YES : NO)];
	
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

- (void)shouldLoadAtStartup:(BOOL)value {
	BOOL exists = NO;
	CFURLRef thePath = (CFURLRef)[[NSBundle mainBundle] bundleURL];
	UInt32 seedValue;
	LSSharedFileListRef loginItems = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
	NSArray *loginItemsArray = (NSArray *)LSSharedFileListCopySnapshot(loginItems, &seedValue);
	LSSharedFileListItemRef removeItem;
	for (id item in loginItemsArray) {
		LSSharedFileListItemRef itemRef = (LSSharedFileListItemRef)item;
		if (LSSharedFileListItemResolve(itemRef, 0, (CFURLRef *)&thePath, NULL) == noErr) {
			if ([[(NSURL *)thePath path] hasSuffix:@"gfxCardStatus.app"]) {
				exists = YES;
				removeItem = (LSSharedFileListItemRef)item;
				if ([gfxCardStatusAppDelegate canLogToConsole])
					NSLog(@"Already exists in startup items.");
			}
		}
	}
	
	if (value && !exists) {
		if ([gfxCardStatusAppDelegate canLogToConsole])
			NSLog(@"Adding to startup items.");
		
		LSSharedFileListItemRef item = LSSharedFileListInsertItemURL(loginItems, kLSSharedFileListItemLast, NULL, NULL, thePath, NULL, NULL);
		
		if (item)
			CFRelease(item);
	} else if (!value && exists) {
		if ([gfxCardStatusAppDelegate canLogToConsole])
			NSLog(@"Removing from startup items.");
		
		LSSharedFileListItemRemove(loginItems, removeItem);
	}
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
