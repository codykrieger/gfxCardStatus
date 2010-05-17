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
#import "proc.h"

#define kLastGPUSettingACAdaptor	@"lastGPUSetting_ACAdaptor"
#define kLastGPUSettingBattery		@"lastGPUSetting_Battery"

// helper to get preference key from PowerSource enum
static inline NSString *keyForPowerSource(PowerSource powerSource) {
	return ((powerSource == psBattery) ? kLastGPUSettingBattery : kLastGPUSettingACAdaptor);
}

// helper to return current mode
switcherMode switcherGetMode() {
	return (switcherUseDynamicSwitching() ? modeDynamicSwitching : (isUsingIntegratedGraphics(NULL) ? modeForceIntel : modeForceNvidia));
}


BOOL canLog = NO;

@implementation gfxCardStatusAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	// set up defaults values if unset
	defaults = [NSUserDefaults standardUserDefaults];
	if ([defaults objectForKey:@"checkForUpdatesOnLaunch"]==nil) [defaults setBool:YES forKey:@"checkForUpdatesOnLaunch"];
	if ([defaults objectForKey:@"useGrowl"]==nil) [defaults setBool:YES forKey:@"useGrowl"];
	if ([defaults objectForKey:@"logToConsole"]==nil) [defaults setBool:NO forKey:@"logToConsole"];
	if ([defaults objectForKey:@"loadAtStartup"]==nil) [defaults setBool:YES forKey:@"loadAtStartup"];
	if ([defaults objectForKey:@"lastGPUSetting"]==nil) [defaults setInteger:3 forKey:@"lastGPUSetting"];
	
	if ([defaults objectForKey:@"lastGPUSetting_ACAdaptor"]==nil) [defaults setInteger:modeDynamicSwitching forKey:kLastGPUSettingACAdaptor];
	if ([defaults objectForKey:@"lastGPUSetting_Battery"]==nil) [defaults setInteger:modeDynamicSwitching forKey:kLastGPUSettingBattery];
	
	// initialize driver and process listing
	canLog = [[defaults objectForKey:@"logToConsole"] boolValue];
	if (!switcherOpen()) Log(@"Can't open driver");
	if (!procInit()) Log(@"Can't obtain I/O Kit's master port");
	
	// set up localized strings
	NSString *version = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
	[versionItem setTitle:[Str(@"About") stringByReplacingOccurrencesOfString:@"%%" withString:version]];
	NSArray* localized = [[NSArray alloc] initWithObjects:updateItem, preferencesItem, quitItem, switchGPUs, intelOnly, nvidiaOnly, dynamicSwitching, dependentProcesses, processList,
						  preferencesWindow, checkForUpdatesOnLaunch, useGrowl, loadAtStartup, logToConsole, closePrefs, aboutWindow, aboutClose, nil];
	for (NSButton* loc in localized) {
		[loc setTitle:Str([loc title])];
	}
	[localized release];
	
	// check for updates if user has them enabled
	if ([defaults boolForKey:@"checkForUpdatesOnLaunch"]) {
		[updater checkForUpdatesInBackground];
	}
	
	// set up growl if necessary
	if ([defaults boolForKey:@"useGrowl"]) {
		[GrowlApplicationBridge setGrowlDelegate:self];
	}
	
	// ensure that application will be loaded at startup
	if ([defaults boolForKey:@"loadAtStartup"]) {
		[self shouldLoadAtStartup:YES];
	}
	
	// preferences window
	[preferencesWindow setLevel:NSModalPanelWindowLevel];
	[preferencesWindow setDelegate:self];
	
	// status item
	[statusMenu setDelegate:self];
	statusItem = [[[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength] retain];
	[statusItem setMenu:statusMenu];
	[statusItem setHighlightMode:YES];
	
	NSNotificationCenter *defaultNotifications = [NSNotificationCenter defaultCenter];
	[defaultNotifications addObserver:self selector:@selector(handleNotification:)
								   name:NSApplicationDidChangeScreenParametersNotification object:nil];
	
	// identify current gpu and set up menus accordingly
	usingIntegrated = isUsingIntegratedGraphics(&usingLegacy);
	[switchGPUs setHidden:!usingLegacy];
	[intelOnly setHidden:usingLegacy];
	[nvidiaOnly setHidden:usingLegacy];
	[dynamicSwitching setHidden:usingLegacy];
	if (usingLegacy) {
		Log(@"Looks like we're using an older 9400M/9600M GT system.");
		
		integratedString = @"NVIDIA® GeForce 9400M";
		discreteString = @"NVIDIA® GeForce 9600M GT";
	} else {
		BOOL dynamic = switcherUseDynamicSwitching();
		[intelOnly setState:(!dynamic && usingIntegrated) ? NSOnState : NSOffState];
		[nvidiaOnly setState:(!dynamic && !usingIntegrated) ? NSOnState : NSOffState];
		[dynamicSwitching setState:dynamic ? NSOnState : NSOffState];
		
		integratedString = @"Intel® HD Graphics";
		discreteString = @"NVIDIA® GeForce GT 330M";
	}
	
	canGrowl = NO;
	[self performSelector:@selector(updateMenuBarIcon)];
	canGrowl = YES;
	
	// monitor power source
	powerSourceMonitor = [PowerSourceMonitor monitorWithDelegate:self];
	lastPowerSource = -1; // uninitialized
	
	// currently ONLY works for Intel/nVIDIA MBPs
	if (usingLegacy) {
		return;
	}
	
	// check current power source and load preference for it
	// the idea is to save user's preference for each power source (battery, adaptor)
	// e.g. user set Intel on Battery and Dynamic on Adaptor and shut down machine with Adaptor attached
	//      next time user unplugs Adaptor and power on
	//		the app should set card to Intel
	//
	// the process is transparent to user
	[self powerSourceChanged:powerSourceMonitor.currentPowerSource];
}

- (IBAction)setMode:(id)sender {
	// legacy cards
	if (sender == switchGPUs) {
		Log(@"Switching GPUs...");
		switcherSetMode(modeToggleGPU);
		return;
	}
	
	// current cards
	if ([sender state] == NSOnState) return;
	
	BOOL retval = NO;
	if (sender == intelOnly) {
		Log(@"Setting Intel only...");
		retval = switcherSetMode(modeForceIntel);
	}
	if (sender == nvidiaOnly) { 
		Log(@"Setting NVIDIA only...");
		retval = switcherSetMode(modeForceNvidia);
	}
	if (sender == dynamicSwitching) {
		Log(@"Setting dynamic switching...");
		retval = switcherSetMode(modeDynamicSwitching);
	}
	
	// only change status in case of success
	if (retval) {
		[intelOnly setState:(sender == intelOnly ? NSOnState : NSOffState)];
		[nvidiaOnly setState:(sender == nvidiaOnly ? NSOnState : NSOffState)];
		[dynamicSwitching setState:(sender == dynamicSwitching ? NSOnState : NSOffState)];
		
		// moved to checkCardStatus
		// save user preference for current power source
		// Log(@"Mode: %d, Power Source: %d\n", switcherGetMode(), powerSourceMonitor.currentPowerSource);
		// [defaults setInteger:switcherGetMode() forKey:keyForPowerSource(powerSourceMonitor.currentPowerSource)];
		
		// delayed double-check
		// only save preference after double-checking
		[self performSelector:@selector(checkCardState) withObject:nil afterDelay:5.0];
	}
}

// Notification observer
// NOTE: If we open the menu while a slow app like Interface Builder is loading, we have the icon not changing
- (void)handleNotification:(NSNotification *)notification {
	Log(@"The following notification has been triggered:\n%@", notification);
	[self updateMenuBarIcon];
}

- (void)menuNeedsUpdate:(NSMenu *)menu {
	//[self updateMenuBarIcon];
	[self updateProcessList];
}

- (void)updateProcessList {
	for (NSMenuItem *mi in [statusMenu itemArray]) {
		if ([mi indentationLevel] > 0 && ![mi isEqual:processList]) [statusMenu removeItem:mi];
	}
	
	// if we're on Intel (or using a 9400M/9600M GT model), no need to display/update the list
	BOOL procList = !usingIntegrated && !usingLegacy;
	[processList setHidden:!procList];
	[processesSeparator setHidden:!procList];
	[dependentProcesses setHidden:!procList];
	if (!procList) return;
	
	Log(@"Updating process list...");
	
	// external display, if connected
	if ([[NSScreen screens] count] > 1) {
		NSMenuItem *externalDisplay = [[NSMenuItem alloc] initWithTitle:@"External Display" action:nil keyEquivalent:@""];
		[externalDisplay setIndentationLevel:1];
		[statusMenu insertItem:externalDisplay atIndex:([statusMenu indexOfItem:processList] + 1)];
	}
	
	NSMutableDictionary* procs = [[NSMutableDictionary alloc] init];
	if (!procGet(procs)) Log(@"Can't obtain I/O Kit's root service");
	
	[processList setHidden:([procs count] > 0)];
	if ([procs count]==0) Log(@"Something's up...we're using the NVIDIA® card, but no process requires it.");
	
	for (NSString* appName in [procs allValues]) {
		NSMenuItem *appItem = [[NSMenuItem alloc] initWithTitle:appName action:nil keyEquivalent:@""];
		[appItem setIndentationLevel:1];
		[statusMenu insertItem:appItem atIndex:([statusMenu indexOfItem:processList] + 1)];
		[appItem release];
	}
	
	[procs release];
}

- (void)updateMenuBarIcon {
	BOOL integrated = switcherUseIntegrated();
	Log(@"Updating status...");
	
	// update icon and labels according to selected GPU
	NSString* cardString = integrated ? integratedString : discreteString;
	[statusItem setImage:[NSImage imageNamed:integrated ? @"intel-3.png" : @"nvidia-3.png"]];
	[currentCard setTitle:[Str(@"Card") stringByReplacingOccurrencesOfString:@"%%" withString:cardString]];
	[currentPowerSource setTitle:(powerSourceMonitor.currentPowerSource == psBattery) ? @"Battery" : @"AC Adaptor"];
	
	if (integrated) Log(@"%@ in use. Sweet deal! More battery life.", integratedString);
	else Log(@"%@ in use. Bummer! No battery life for you.", discreteString);
	
	if ([defaults boolForKey:@"useGrowl"] && canGrowl && usingIntegrated != integrated) {
		NSString *msg  = [NSString stringWithFormat:@"%@ now in use.", cardString];
		NSString *name = integrated ? @"switchedToIntegrated" : @"switchedToDiscrete";
		[GrowlApplicationBridge notifyWithTitle:@"GPU changed" description:msg notificationName:name iconData:nil priority:0 isSticky:NO clickContext:nil];
	}
	
	usingIntegrated = integrated;
	if (!integrated) [self updateProcessList];
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

// NSWindowDelegate for preferences window
- (void)windowWillClose:(NSNotification *)notification {
	// save values to defaults
	[defaults setBool:([checkForUpdatesOnLaunch state] > 0 ? YES : NO) forKey:@"checkForUpdatesOnLaunch"];
	[defaults setBool:([useGrowl state] > 0 ? YES : NO) forKey:@"useGrowl"];
	[defaults setBool:([logToConsole state] > 0 ? YES : NO) forKey:@"logToConsole"];
	[defaults setBool:([loadAtStartup state] > 0 ? YES : NO) forKey:@"loadAtStartup"];
	canLog = [defaults boolForKey:@"logToConsole"];
	[self shouldLoadAtStartup:[defaults boolForKey:@"loadAtStartup"]];
}

- (IBAction)savePreferences:(id)sender {
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
	NSURL *thePath = [[NSBundle mainBundle] bundleURL];
	LSSharedFileListRef loginItems = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
	if (loginItems) {
		UInt32 seedValue;
		NSArray *loginItemsArray = (NSArray *)LSSharedFileListCopySnapshot(loginItems, &seedValue);
		LSSharedFileListItemRef removeItem;
		for (id item in loginItemsArray) {
			LSSharedFileListItemRef itemRef = (LSSharedFileListItemRef)item;
			CFURLRef URL = NULL;
			if (LSSharedFileListItemResolve(itemRef, 0, &URL, NULL) == noErr) {
				if ([[(NSURL *)URL path] hasSuffix:@"gfxCardStatus.app"]) {
					exists = YES;
					CFRelease(URL);
					removeItem = (LSSharedFileListItemRef)item;
					Log(@"Already exists in startup items.");
					break;
				}
			}
		}
		
		if (value && !exists) {
			Log(@"Adding to startup items.");
			LSSharedFileListItemRef item = LSSharedFileListInsertItemURL(loginItems, kLSSharedFileListItemBeforeFirst, NULL, NULL, (CFURLRef)thePath, NULL, NULL);
			if (item) CFRelease(item);
		} else if (!value && exists) {
			Log(@"Removing from startup items.");		
			LSSharedFileListItemRemove(loginItems, removeItem);
		}
		
		CFRelease(loginItems);
	}
}

- (IBAction)quit:(id)sender {
	[[NSApplication sharedApplication] terminate:self];
}

- (void)dealloc {
	procFree(); // Free processes listing buffers
	switcherClose(); // Close driver
	
	[statusItem release];
	[super dealloc];
}

// convert switcher mode to a menu item (consumed by setMode:)
- (NSMenuItem *)senderForMode:(switcherMode)mode {
	switch (mode) {
		case modeForceIntel:
			return intelOnly;
		case modeForceNvidia:
			return nvidiaOnly;
		case modeDynamicSwitching:
			return dynamicSwitching;
	}
	
	return dynamicSwitching;
}

- (void)powerSourceChanged:(PowerSource)powerSource {
	if (powerSource == lastPowerSource) {
		Log(@"Power Source UNCHANGED: false alarm (maybe a wake-up?)\n");
		return;
	}
	
	Log(@"Power Source Changed: %d -> %d\n", lastPowerSource, powerSource);
	lastPowerSource = powerSource;
	
	switcherMode newMode = [[defaults objectForKey:keyForPowerSource(powerSource)] intValue];
	
	[self setMode:[self senderForMode:newMode]];
	[self updateMenuBarIcon];
}

// it seems right after waking-up, locking to single GPU will fail (even if the return value is correct)
// this is a temporary walk-around to double-check the status
- (void)checkCardState {
	switcherMode currentMode = switcherGetMode(); // ACTUAL current mode
	NSMenuItem *activeCard = [self senderForMode:currentMode]; // corresponding menu item
	
	// check if its consistent with menu state
	if (activeCard.state != NSOnState) { // inconsistent, forcing retry
		Log(@"Inconsistent menu state and actual card, forcing retry\n");
		lastPowerSource = -1; // set to uninitialized, forcing retry
		
		// set menu item to reflect actual status
		intelOnly.state = NSOffState;
		nvidiaOnly.state = NSOffState;
		dynamicSwitching.state = NSOffState;
		activeCard.state = NSOnState;
		
		[self powerSourceChanged:powerSourceMonitor.currentPowerSource];
		
		return;
	}
	
	// save user preference for current power source and card choice combination
	Log(@"Mode: %d, Power Source: %d\n", switcherGetMode(), powerSourceMonitor.currentPowerSource);
	[defaults setInteger:switcherGetMode() forKey:keyForPowerSource(powerSourceMonitor.currentPowerSource)];
}

@end
