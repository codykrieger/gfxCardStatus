//
//  GSPreferences.m
//  gfxCardStatus
//
//  Created by Cody Krieger on 9/26/10.
//  Copyright 2010 Cody Krieger. All rights reserved.
//

#import "GSPreferences.h"
#import "GSStartup.h"
#import "GSGPU.h"

// Unfortunately this value needs to stay misspelled unless there is a desire to
// migrate it to a correctly spelled version instead, since getting and setting
// the existing preferences depend on it.
#define kGPUSettingACAdapter                    @"GPUSetting_ACAdaptor"
#define kGPUSettingBattery                      @"GPUSetting_Battery"

#define kShouldStartAtLoginKey                  @"shouldStartAtLogin"
#define kShouldUseImageIconsKey                 @"shouldUseImageIcons"
#define kShouldCheckForUpdatesOnStartupKey      @"shouldCheckForUpdatesOnStartup"
#define kShouldUsePowerSourceBasedSwitchingKey  @"shouldUsePowerSourceBasedSwitching"
#define kShouldUseSmartMenuBarIconsKey          @"shouldUseSmartMenuBarIcons"

// Why aren't we just using NSUserDefaults? Because it was unbelievably
// unreliable. This works all the time, no questions asked.
#define kPreferencesPlistPath [@"~/Library/Preferences/com.codykrieger.gfxCardStatus-Preferences.plist" stringByExpandingTildeInPath]

@interface GSPreferences ()
- (NSString *)_getPrefsPath;
@end

@implementation GSPreferences

@synthesize prefsDict = _prefsDict;

#pragma mark - Initializers

- (id)init
{
    if ((self = [super init])) {
        GTMLoggerDebug(@"Initializing GSPreferences...");
        [self setUpPreferences];
    }
    return self;
}

+ (GSPreferences *)sharedInstance
{
    static dispatch_once_t pred = 0;
    __strong static GSPreferences *_sharedObject = nil;
    dispatch_once(&pred, ^{
        _sharedObject = [[self alloc] init]; // or some other init method
    });
    return _sharedObject;
}

#pragma mark - GSPreferences API

- (void)setUpPreferences
{
    GTMLoggerDebug(@"Loading preferences and defaults...");
    
    // load preferences in from file
    _prefsDict = [[NSMutableDictionary alloc] initWithContentsOfFile:[self _getPrefsPath]];
    
    if (!_prefsDict) {
        // if preferences file doesn't exist, set the defaults
        _prefsDict = [[NSMutableDictionary alloc] init];
        [self setDefaults];
    }
    
    _prefsDict[kShouldStartAtLoginKey] = @([GSStartup existsInStartupItems]);
    
    // ensure that application will be loaded at startup
    if ([self shouldStartAtLogin])
        [GSStartup loadAtStartup:YES];
    
    _prefsDict[kShouldUseImageIconsKey] = @(!![[NSBundle mainBundle] pathForResource:@"integrated" ofType:@"png"]);
}

- (void)setDefaults
{
    GTMLoggerDebug(@"Setting initial defaults...");
    
    _prefsDict[kShouldCheckForUpdatesOnStartupKey] = @YES;
    _prefsDict[kShouldStartAtLoginKey] = @YES;
    _prefsDict[kShouldUsePowerSourceBasedSwitchingKey] = @NO;
    _prefsDict[kShouldUseSmartMenuBarIconsKey] = @NO;
    
    _prefsDict[kGPUSettingBattery] = @0; // defaults to integrated
    if ([GSGPU isLegacyMachine])
        _prefsDict[kGPUSettingACAdapter] = @1; // defaults to discrete for legacy machines
    else
        _prefsDict[kGPUSettingACAdapter] = @2; // defaults to dynamic for new machines
    
    [self savePreferences];
}

- (void)savePreferences
{
    GTMLoggerDebug(@"Writing preferences to disk...");
    
    if ([_prefsDict writeToFile:[self _getPrefsPath] atomically:YES]) {
        GTMLoggerDebug(@"Successfully wrote preferences to disk.");
    } else {
        GTMLoggerDebug(@"Failed to write preferences to disk. Permissions problem in ~/Library/Preferences?");
    }
}

- (void)setBool:(BOOL)value forKey:(NSString *)key
{
    _prefsDict[key] = @(value);
    [self savePreferences];
}

- (BOOL)boolForKey:(NSString *)key
{
    return [_prefsDict[key] boolValue];
}

- (BOOL)shouldCheckForUpdatesOnStartup
{
    return [_prefsDict[kShouldCheckForUpdatesOnStartupKey] boolValue];
}

- (BOOL)shouldStartAtLogin
{
    return [_prefsDict[kShouldStartAtLoginKey] boolValue];
}

- (BOOL)shouldUsePowerSourceBasedSwitching
{
    return [_prefsDict [kShouldUsePowerSourceBasedSwitchingKey] boolValue];
}

- (BOOL)shouldUseImageIcons
{
    return [_prefsDict[kShouldUseImageIconsKey] boolValue];
}

- (BOOL)shouldUseSmartMenuBarIcons
{
    return [_prefsDict[kShouldUseSmartMenuBarIconsKey] boolValue];
}

- (int)modeForPowerSource:(NSString *)powerSource
{
    return [_prefsDict[powerSource] intValue];
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
