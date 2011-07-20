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

@interface PrefsController (Private)

- (void)copyLoginItems:(LSSharedFileListRef *)loginItems andCurrentLoginItem:(LSSharedFileListItemRef *)currentItem;

@end

@implementation PrefsController

#pragma mark -
#pragma mark class instance methods

- (id)init {
    if ((self = [super init])) {
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
    
    if ([[NSBundle mainBundle] pathForResource:@"integrated" ofType:@"png"])
        [prefs setObject:yesNumber forKey:@"shouldUseImageIcons"];
    else
        [prefs setObject:noNumber forKey:@"shouldUseImageIcons"];
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

- (void)savePreferences {
    DLog(@"Writing preferences to disk");
    
    if ([prefs writeToFile:[self getPrefsPath] atomically:YES]) {
        DLog(@"Successfully wrote preferences to disk.");
    } else {
        DLog(@"Failed to write preferences to disk. Permissions problem in ~/Library/Preferences?");
    }
}

- (void)windowWillClose:(NSNotification *)notification {
    [self savePreferences];
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

- (BOOL)shouldUseImageIcons {
    return [(NSNumber *)[prefs objectForKey:@"shouldUseImageIcons"] boolValue];
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

- (void)copyLoginItems:(LSSharedFileListRef *)loginItems andCurrentLoginItem:(LSSharedFileListItemRef *)currentItem {
    *loginItems = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
    
    if (*loginItems) {
        UInt32 seedValue;
        NSArray *loginItemsArray = (NSArray *)LSSharedFileListCopySnapshot(*loginItems, &seedValue);
        
        for (id item in loginItemsArray) {
            LSSharedFileListItemRef itemRef = (LSSharedFileListItemRef)item;
            CFURLRef URL = NULL;
            
            if (LSSharedFileListItemResolve(itemRef, 0, &URL, NULL) == noErr) {
                if ([[(NSURL *)URL path] hasSuffix:@"gfxCardStatus.app"]) {
                    DLog(@"Exists in startup items.");
                    
                    *currentItem = (LSSharedFileListItemRef)item;
                    CFRetain(*currentItem);
                    
                    CFRelease(URL);
                    
                    break;
                }
                
                CFRelease(URL);
            }
        }
        
        [loginItemsArray release];
    }
}

- (BOOL)existsInStartupItems {
    BOOL exists;
    LSSharedFileListRef loginItems = NULL;
    LSSharedFileListItemRef currentItem = NULL;
    
    [self copyLoginItems:&loginItems andCurrentLoginItem:&currentItem];
    
    exists = (currentItem != NULL);
    
    if (loginItems != NULL)
        CFRelease(loginItems);
    if (currentItem != NULL)
        CFRelease(currentItem);
    
    return exists;
}

- (void)loadAtStartup:(BOOL)value {
    NSURL *thePath = [[NSBundle mainBundle] bundleURL];
    LSSharedFileListRef loginItems = NULL;
    LSSharedFileListItemRef currentItem = NULL;
    
    [self copyLoginItems:&loginItems andCurrentLoginItem:&currentItem];
    
    if (loginItems) {
        if (value && currentItem == NULL) {
            DLog(@"Adding to startup items.");
            LSSharedFileListItemRef item = LSSharedFileListInsertItemURL(loginItems, kLSSharedFileListItemBeforeFirst, NULL, NULL, (CFURLRef)thePath, NULL, NULL);
            if (item) CFRelease(item);
        } else if (!value && currentItem != NULL) {
            DLog(@"Removing from startup items.");        
            LSSharedFileListItemRemove(loginItems, currentItem);
        }
        
        CFRelease(loginItems);
        if (currentItem)
            CFRelease(currentItem);
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
