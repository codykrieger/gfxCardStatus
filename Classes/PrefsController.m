//
//  PrefsController.m
//  gfxCardStatus
//
//  Created by Cody Krieger on 9/26/10.
//  Copyright 2010 Cody Krieger. All rights reserved.
//

#import "PrefsController.h"
#import "GSStartup.h"
#import "GSGPU.h"

#define kPreferencesPlistPath [@"~/Library/Preferences/com.codykrieger.gfxCardStatus-Preferences.plist" stringByExpandingTildeInPath]

@interface PrefsController ()
- (NSString *)_getPrefsPath;
@end

@implementation PrefsController

#pragma mark - Initializers

- (id)init
{
    if ((self = [super init])) {
        GTMLoggerDebug(@"Initializing PrefsController");
        [self setUpPreferences];
    }
    return self;
}

+ (PrefsController *)sharedInstance
{
    static dispatch_once_t pred = 0;
    __strong static PrefsController *_sharedObject = nil;
    dispatch_once(&pred, ^{
        _sharedObject = [[self alloc] init]; // or some other init method
    });
    return _sharedObject;
}

#pragma mark - PrefsController API

- (void)setUpPreferences
{
    GTMLoggerDebug(@"Loading preferences and defaults");
    
    // set yes/no numbers
    yesNumber = [NSNumber numberWithBool:YES];
    noNumber = [NSNumber numberWithBool:NO];
    
    // load preferences in from file
    prefs = [[NSMutableDictionary alloc] initWithContentsOfFile:[self _getPrefsPath]];
    if (!prefs) {
        // if preferences file doesn't exist, set the defaults
        prefs = [[NSMutableDictionary alloc] init];
        [self setDefaults];
    } else {
        if ([GSStartup existsInStartupItems])
            [prefs setObject:yesNumber forKey:@"shouldStartAtLogin"];
        else
            [prefs setObject:noNumber forKey:@"shouldStartAtLogin"];
    }
    
    // ensure that application will be loaded at startup
    if ([self shouldStartAtLogin])
        [GSStartup loadAtStartup:YES];
    
    if ([[NSBundle mainBundle] pathForResource:@"integrated" ofType:@"png"])
        [prefs setObject:yesNumber forKey:@"shouldUseImageIcons"];
    else
        [prefs setObject:noNumber forKey:@"shouldUseImageIcons"];
}

- (void)setDefaults
{
    GTMLoggerDebug(@"Setting initial defaults...");
    
    [prefs setObject:yesNumber forKey:@"shouldCheckForUpdatesOnStartup"];
    [prefs setObject:yesNumber forKey:@"shouldGrowl"];
    [prefs setObject:yesNumber forKey:@"shouldStartAtLogin"];
    [prefs setObject:noNumber forKey:@"shouldUsePowerSourceBasedSwitching"];
    [prefs setObject:noNumber forKey:@"shouldUseSmartMenuBarIcons"];
    
    [prefs setObject:[NSNumber numberWithInt:0] forKey:kGPUSettingBattery]; // defaults to integrated
    if ([GSGPU isLegacyMachine])
        [prefs setObject:[NSNumber numberWithInt:1] forKey:kGPUSettingACAdaptor]; // defaults to discrete for legacy machines
    else
        [prefs setObject:[NSNumber numberWithInt:2] forKey:kGPUSettingACAdaptor]; // defaults to dynamic for new machines
    
    [self savePreferences];
}

- (void)savePreferences
{
    GTMLoggerDebug(@"Writing preferences to disk...");
    
    if ([prefs writeToFile:[self _getPrefsPath] atomically:YES]) {
        GTMLoggerDebug(@"Successfully wrote preferences to disk.");
    } else {
        GTMLoggerDebug(@"Failed to write preferences to disk. Permissions problem in ~/Library/Preferences?");
    }
}

- (void)setBool:(BOOL)value forKey:(NSString *)key
{
    [prefs setObject:(value ? yesNumber : noNumber) forKey:key];
    [self savePreferences];
}

- (BOOL)boolForKey:(NSString *)key
{
    return [(NSNumber *)[prefs objectForKey:key] boolValue];
}

- (BOOL)shouldCheckForUpdatesOnStartup
{
    return [(NSNumber *)[prefs objectForKey:@"shouldCheckForUpdatesOnStartup"] boolValue];
}

- (BOOL)shouldStartAtLogin
{
    return [(NSNumber *)[prefs objectForKey:@"shouldStartAtLogin"] boolValue];
}

- (BOOL)shouldUsePowerSourceBasedSwitching
{
    return [(NSNumber *)[prefs objectForKey:@"shouldUsePowerSourceBasedSwitching"] boolValue];
}

- (BOOL)shouldUseImageIcons
{
    return [(NSNumber *)[prefs objectForKey:@"shouldUseImageIcons"] boolValue];
}

- (BOOL)shouldUseSmartMenuBarIcons
{
    return [(NSNumber *)[prefs objectForKey:@"shouldUseSmartMenuBarIcons"] boolValue];
}

- (int)modeForPowerSource:(NSString *)powerSource
{
    return [(NSNumber *)[prefs objectForKey:powerSource] intValue];
}

#pragma mark - NSWindowDelegate protocol

- (void)windowWillClose:(NSNotification *)notification
{
    [self savePreferences];
}

#pragma mark - Private helpers

- (NSString *)_getPrefsPath
{
    return kPreferencesPlistPath;
}

@end
