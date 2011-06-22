//
//  PrefsController.m
//  gfxCardStatus
//
//  Created by Cody Krieger on 9/26/10.
//  Copyright 2010 Cody Krieger. All rights reserved.
//

#import "PrefsController.h"
#import "SessionMagic.h"

static PrefsController *sharedInstance = nil;

@implementation PrefsController

#pragma mark -
#pragma mark class instance methods

- (id)init {
    if ((self = [super initWithWindowNibName:@"PrefsWindow"])) {
        DLog(@"Initializing PrefsController");
        [self setUpPreferences];
    }
    return self;
}

- (void)setUpPreferences {
    DLog(@"Loading preferences and defaults");
    
    // set yes/no numbers
    yesNumber = [NSNumber numberWithBool:YES];
    noNumber = [NSNumber numberWithBool:NO];
    
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
    NSArray* localizedButtons = [[NSArray alloc] initWithObjects:prefChkGrowl, prefChkLog, prefChkPowerSourceBasedSwitching, 
                          prefChkRestoreState, prefChkStartup, prefChkUpdate, nil];
    for (NSButton *loc in localizedButtons) {
        [loc setTitle:Str([loc title])];
    }
    [localizedButtons release];
    
    NSArray *localizedLabels = [[NSArray alloc] initWithObjects:onBatteryTextField, pluggedInTextField, nil];
    for (NSTextField *field in localizedLabels) {
        [field setStringValue:Str([field stringValue])];
    }
    [localizedLabels release];
    
    if ([[SessionMagic sharedInstance] usingLegacy]) {
        [prefSegOnBattery setSegmentCount:2];
        [prefSegOnAc setSegmentCount:2];
    } else {
        [prefSegOnBattery setLabel:Str(@"Dynamic") forSegment:2];
        [prefSegOnAc setLabel:Str(@"Dynamic") forSegment:2];
    }
    
    [prefSegOnBattery setLabel:Str(@"Integrated") forSegment:0];
    [prefSegOnBattery setLabel:Str(@"Discrete") forSegment:1];
    [prefSegOnAc setLabel:Str(@"Integrated") forSegment:0];
    [prefSegOnAc setLabel:Str(@"Discrete") forSegment:1];
    
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
    DLog(@"Setting initial defaults...");
    
    [prefs setObject:yesNumber forKey:@"shouldCheckForUpdatesOnStartup"];
    [prefs setObject:yesNumber forKey:@"shouldGrowl"];
    [prefs setObject:yesNumber forKey:@"shouldStartAtLogin"];
    [prefs setObject:yesNumber forKey:@"shouldRestoreStateOnStartup"];
    [prefs setObject:noNumber forKey:@"shouldUsePowerSourceBasedSwitching"];
    
    [prefs setObject:[NSNumber numberWithInt:0] forKey:kGPUSettingBattery]; // defaults to integrated
    if ([[SessionMagic sharedInstance] usingLegacy])
        [prefs setObject:[NSNumber numberWithInt:1] forKey:kGPUSettingACAdaptor]; // defaults to discrete for legacy machines
    else
        [prefs setObject:[NSNumber numberWithInt:2] forKey:kGPUSettingACAdaptor]; // defaults to dynamic for new machines
    
    // last mode used before termination
    [prefs setObject:[NSNumber numberWithInt:2] forKey:@"shouldRestoreToMode"];
    
    [self savePreferences];
}

- (void)setControlsToPreferences {
    DLog(@"Setting controls to mirror saved preferences");
    
    [prefChkUpdate setState:[self shouldCheckForUpdatesOnStartup]];
    [prefChkGrowl setState:[self shouldGrowl]];
    [prefChkStartup setState:[self shouldStartAtLogin]];
    
    [prefChkRestoreState setState:[self shouldRestoreStateOnStartup]];
    [prefChkPowerSourceBasedSwitching setState:[self shouldUsePowerSourceBasedSwitching]];
    [prefChkRestoreState setEnabled:![self shouldUsePowerSourceBasedSwitching]];
    
    [prefSegOnBattery setSelectedSegment:[self modeForPowerSource:kGPUSettingBattery]];
    [prefSegOnAc setSelectedSegment:[self modeForPowerSource:kGPUSettingACAdaptor]];
}

- (void)savePreferences {
//    DLog(@"Writing preferences to disk");
    
    if ([prefs writeToFile:[self getPrefsPath] atomically:YES]) {
//        DLog(@"Successfully wrote preferences to disk.");
    } else {
//        DLog(@"Failed to write preferences to disk. Permissions problem in ~/Library/Preferences?");
    }
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
                    DLog(@"Already exists in startup items");
                    CFRelease(URL);
                    removeItem = (LSSharedFileListItemRef)item;
                    break;
                }
            }
        }
        
        if (value && !exists) {
            DLog(@"Adding to startup items.");
            LSSharedFileListItemRef item = LSSharedFileListInsertItemURL(loginItems, kLSSharedFileListItemBeforeFirst, NULL, NULL, (CFURLRef)thePath, NULL, NULL);
            if (item) CFRelease(item);
        } else if (!value && exists) {
            DLog(@"Removing from startup items.");        
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

- (oneway void)release {
    // do nothing
}

- (id)autorelease {
    return self;
}

@end
