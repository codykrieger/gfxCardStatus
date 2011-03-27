//
//  PrefsController.m
//  gfxCardStatus
//
//  Created by Cody Krieger on 9/26/10.
//  Copyright 2010 Cody Krieger. All rights reserved.
//

#import "PrefsController.h"
#import "systemProfiler.h"

static PrefsController *sharedInstance = nil;

@implementation PrefsController

@synthesize usingLegacy;

#pragma mark -
#pragma mark class instance methods

- (id)init {
    if ((self = [super initWithWindowNibName:@"PrefsWindow"])) {
        Log(@"Initializing PrefsController");
        [self setUpPreferences];
    }
    return self;
}

- (void)setUpPreferences {
    Log(@"Loading preferences and defaults");
    
    // set yes/no numbers
    yesNumber = [NSNumber numberWithBool:YES];
    noNumber = [NSNumber numberWithBool:NO];
    
    NSDictionary *profile = getGraphicsProfile();
    usingLegacy = [(NSNumber *)[profile objectForKey:@"legacy"] boolValue];
    
    // load preferences in from file
    prefs = [[NSMutableDictionary alloc] initWithContentsOfFile:[self getPrefsPath]];
    if (!prefs) {
        // if preferences file doesn't exist, set the defaults
        prefs = [[NSMutableDictionary alloc] init];
        [self setDefaults];
    } else {
        if ([self existsInStartupItems])
            [prefs setObject:yesNumber forKey:@"shouldStartAtLogin"];
        else
            [prefs setObject:noNumber forKey:@"shouldStartAtLogin"];
    }
    
    // ensure that application will be loaded at startup
    if ([self shouldStartAtLogin])
        [self loadAtStartup:YES];
}

- (void)awakeFromNib {
    // localization
    NSArray* localized = [[NSArray alloc] initWithObjects:prefChkGrowl, prefChkLog, prefChkPowerSourceBasedSwitching, 
                          prefChkRestoreState, prefChkStartup, prefChkUpdate, nil];
    for (NSButton *loc in localized) {
        [loc setTitle:Str([loc title])];
    }
    [localized release];
    
    if (usingLegacy) {
        [prefSegOnBattery setSegmentCount:2];
        for (int i = 0; i < [prefSegOnBattery segmentCount]; i++) {
            [prefSegOnBattery setLabel:Str([prefSegOnBattery labelForSegment:i]) forSegment:i];
        }
        [prefSegOnAc setSegmentCount:2];
        for (int i = 0; i < [prefSegOnAc segmentCount]; i++) {
            [prefSegOnAc setLabel:Str([prefSegOnAc labelForSegment:i]) forSegment:i];
        }
    } else {
        [prefSegOnBattery setLabel:@"Integrated" forSegment:0];
        [prefSegOnBattery setLabel:@"Discrete" forSegment:1];
        [prefSegOnAc setLabel:@"Integrated" forSegment:0];
        [prefSegOnAc setLabel:@"Discrete" forSegment:1];
    }
    
    // set controls according to values set in preferences
    [self setControlsToPreferences];
    
    // preferences window
    [[self window] setLevel:NSModalPanelWindowLevel];
    [[self window] setDelegate:self];
}

- (NSString *)getPrefsPath {
    return [@"~/Library/Preferences/com.codykrieger.gfxCardStatus-Preferences.plist" stringByExpandingTildeInPath];
}

- (void)setDefaults {
    Log(@"Setting initial defaults...");
    
    [prefs setObject:yesNumber forKey:@"shouldCheckForUpdatesOnStartup"];
    [prefs setObject:yesNumber forKey:@"shouldGrowl"];
    [prefs setObject:yesNumber forKey:@"shouldStartAtLogin"];
    [prefs setObject:yesNumber forKey:@"shouldLogToConsole"];
    [prefs setObject:yesNumber forKey:@"shouldRestoreStateOnStartup"];
    [prefs setObject:noNumber forKey:@"shouldUsePowerSourceBasedSwitching"];
    
    [prefs setObject:[NSNumber numberWithInt:0] forKey:kGPUSettingBattery]; // defaults to integrated
    if (usingLegacy)
        [prefs setObject:[NSNumber numberWithInt:1] forKey:kGPUSettingACAdaptor]; // defaults to discrete for legacy machines
    else
        [prefs setObject:[NSNumber numberWithInt:2] forKey:kGPUSettingACAdaptor]; // defaults to dynamic for new machines
    
    // last mode used before termination
    [prefs setObject:[NSNumber numberWithInt:2] forKey:@"shouldRestoreToMode"];
    
    [self savePreferences];
}

- (void)setControlsToPreferences {
    Log(@"Setting controls to mirror saved preferences");
    
    [prefChkUpdate setState:[self shouldCheckForUpdatesOnStartup]];
    [prefChkGrowl setState:[self shouldGrowl]];
    [prefChkStartup setState:[self shouldStartAtLogin]];
    [prefChkLog setState:[self shouldLogToConsole]];
    
    [prefChkRestoreState setState:[self shouldRestoreStateOnStartup]];
    [prefChkPowerSourceBasedSwitching setState:[self shouldUsePowerSourceBasedSwitching]];
    [prefChkRestoreState setEnabled:![self shouldUsePowerSourceBasedSwitching]];
    
    [prefSegOnBattery setSelectedSegment:[self modeForPowerSource:kGPUSettingBattery]];
    [prefSegOnAc setSelectedSegment:[self modeForPowerSource:kGPUSettingACAdaptor]];
}

- (void)savePreferences {
    Log(@"Writing preferences to disk");
    
    if ([prefs writeToFile:[self getPrefsPath] atomically:YES])
        Log(@"Successfully wrote preferences to disk.");
    else
        Log(@"Failed to write preferences to disk. Permissions problem in ~/Library/Preferences?");
}

- (void)openPreferences {
    [[self window] makeKeyAndOrderFront:nil];
    [[self window] orderFrontRegardless];
    [[self window] center];
}

- (void)windowWillClose:(NSNotification *)notification {
    [self savePreferences];
}

- (IBAction)preferenceChanged:(id)sender {
    if (sender == prefChkUpdate) {
        [prefs setObject:([prefChkUpdate state] ? yesNumber : noNumber) forKey:@"shouldCheckForUpdatesOnStartup"];
    } else if (sender == prefChkGrowl) {
        [prefs setObject:([prefChkGrowl state] ? yesNumber : noNumber) forKey:@"shouldGrowl"];
    } else if (sender == prefChkStartup) {
        [prefs setObject:([prefChkStartup state] ? yesNumber : noNumber) forKey:@"shouldStartAtLogin"];
        [self loadAtStartup:([prefChkStartup state] ? YES : NO)];
    } else if (sender == prefChkLog) {
        [prefs setObject:([prefChkLog state] ? yesNumber : noNumber) forKey:@"shouldLogToConsole"];
        canLog = ([prefChkLog state] ? YES : NO);
    } else if (sender == prefChkRestoreState) {
        [prefs setObject:([prefChkRestoreState state] ? yesNumber : noNumber) forKey:@"shouldRestoreStateOnStartup"];
    } else if (sender == prefChkPowerSourceBasedSwitching) {
        [prefs setObject:([prefChkPowerSourceBasedSwitching state] ? yesNumber : noNumber) forKey:@"shouldUsePowerSourceBasedSwitching"];
        [prefChkRestoreState setEnabled:![self shouldUsePowerSourceBasedSwitching]];
    } else if (sender == prefSegOnBattery) {
        [prefs setObject:[NSNumber numberWithInt:[prefSegOnBattery selectedSegment]] forKey:kGPUSettingBattery];
    } else if (sender == prefSegOnAc) {
        [prefs setObject:[NSNumber numberWithInt:[prefSegOnAc selectedSegment]] forKey:kGPUSettingACAdaptor];
    }
}

- (void)setBool:(BOOL)value forKey:(NSString *)key {
    [prefs setObject:(value ? yesNumber : noNumber) forKey:key];
    [self savePreferences];
}

- (BOOL)boolForKey:(NSString *)key {
    return [(NSNumber *)[prefs objectForKey:key] boolValue];
}

- (BOOL)shouldCheckForUpdatesOnStartup {
    return [(NSNumber *)[prefs objectForKey:@"shouldCheckForUpdatesOnStartup"] boolValue];
}

- (BOOL)shouldGrowl {
    return [(NSNumber *)[prefs objectForKey:@"shouldGrowl"] boolValue];
}

- (BOOL)shouldStartAtLogin {
    return [(NSNumber *)[prefs objectForKey:@"shouldStartAtLogin"] boolValue];
}

- (BOOL)shouldLogToConsole {
    return [(NSNumber *)[prefs objectForKey:@"shouldLogToConsole"] boolValue];
}

- (BOOL)shouldRestoreStateOnStartup {
    return [(NSNumber *)[prefs objectForKey:@"shouldRestoreStateOnStartup"] boolValue];
}

- (BOOL)shouldUsePowerSourceBasedSwitching {
    return [(NSNumber *)[prefs objectForKey:@"shouldUsePowerSourceBasedSwitching"] boolValue];
}

- (int)shouldRestoreToMode {
    return [(NSNumber *)[prefs objectForKey:@"shouldRestoreToMode"] intValue];
}

- (int)modeForPowerSource:(NSString *)powerSource {
    return [(NSNumber *)[prefs objectForKey:powerSource] intValue];
}

- (void)setLastMode:(int)value {
    [prefs setObject:[NSNumber numberWithInt:value] forKey:@"shouldRestoreToMode"];
    [self savePreferences];
}

- (BOOL)existsInStartupItems {
    BOOL exists = NO;
    LSSharedFileListRef loginItems = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
    if (loginItems) {
        UInt32 seedValue;
        NSArray *loginItemsArray = (NSArray *)LSSharedFileListCopySnapshot(loginItems, &seedValue);
        for (id item in loginItemsArray) {
            LSSharedFileListItemRef itemRef = (LSSharedFileListItemRef)item;
            CFURLRef URL = NULL;
            if (LSSharedFileListItemResolve(itemRef, 0, &URL, NULL) == noErr) {
                if ([[(NSURL *)URL path] hasSuffix:@"gfxCardStatus.app"]) {
                    exists = YES;
                    CFRelease(URL);
                    break;
                }
            }
        }
        
        [loginItemsArray release];
        CFRelease(loginItems);
    }
    return exists;
}

- (void)loadAtStartup:(BOOL)value {
    NSURL *thePath = [[NSBundle mainBundle] bundleURL];
    LSSharedFileListRef loginItems = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
    if (loginItems) {
        BOOL exists = NO;
        
        UInt32 seedValue;
        NSArray *loginItemsArray = (NSArray *)LSSharedFileListCopySnapshot(loginItems, &seedValue);
        LSSharedFileListItemRef removeItem;
        for (id item in loginItemsArray) {
            LSSharedFileListItemRef itemRef = (LSSharedFileListItemRef)item;
            CFURLRef URL = NULL;
            if (LSSharedFileListItemResolve(itemRef, 0, &URL, NULL) == noErr) {
                if ([[(NSURL *)URL path] hasSuffix:@"gfxCardStatus.app"]) {
                    exists = YES;
                    Log(@"Already exists in startup items");
                    CFRelease(URL);
                    removeItem = (LSSharedFileListItemRef)item;
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
        
        [loginItemsArray release];
        CFRelease(loginItems);
    }
}

#pragma mark -
#pragma mark Singleton methods

+ (PrefsController *)sharedInstance {
    @synchronized(self) {
        if (sharedInstance == nil)
            sharedInstance = [[PrefsController alloc] init];
    }
    return sharedInstance;
}

+ (id)allocWithZone:(NSZone *)zone {
    @synchronized(self) {
        if (sharedInstance == nil) {
            sharedInstance = [super allocWithZone:zone];
            return sharedInstance; // assignment and return on first allocation
        }
    }
    return nil; // on subsequent allocation attempts return nil
}

- (id)copyWithZone:(NSZone *)zone {
    return self;
}

- (id)retain {
    return self;
}

- (NSUInteger)retainCount {
    return NSUIntegerMax; // denotes an object that cannot be released
}

- (void)release {
}

- (id)autorelease {
    return self;
}

@end
