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
#define kPowerSourceBasedSwitchingACMode        @"GPUSetting_ACAdaptor"
#define kPowerSourceBasedSwitchingBatteryMode   @"GPUSetting_Battery"

#define kShouldStartAtLoginKey                  @"shouldStartAtLogin"
#define kShouldUseImageIconsKey                 @"shouldUseImageIcons"
#define kShouldCheckForUpdatesOnStartupKey      @"shouldCheckForUpdatesOnStartup"
#define kShouldUsePowerSourceBasedSwitchingKey  @"shouldUsePowerSourceBasedSwitching"
#define kShouldUseSmartMenuBarIconsKey          @"shouldUseSmartMenuBarIcons"

// This used to be called "shouldGrowl"
#define kShouldDisplayNotificationsKey          @"shouldGrowl"

// Why aren't we just using NSUserDefaults? Because it was unbelievably
// unreliable. This works all the time, no questions asked.
#define kPreferencesPlistPath [@"~/Library/Preferences/com.codykrieger.gfxCardStatus-Preferences.plist" stringByExpandingTildeInPath]

@interface GSPreferences (Internal)
- (NSString *)_getPrefsPath;
@end

@implementation GSPreferences

@synthesize prefsDict = _prefsDict;

#pragma mark - Initializers

- (id)init
{
    if (!(self = [super init]))
        return nil;
    
    GSLogDebug(@"Initializing GSPreferences...");
    [self setUpPreferences];
    
    return self;
}

+ (GSPreferences *)sharedInstance
{
    static dispatch_once_t pred = 0;
    __strong static GSPreferences *_sharedObject = nil;
    dispatch_once(&pred, ^{
        _sharedObject = [[self alloc] init];
    });
    return _sharedObject;
}

#pragma mark - GSPreferences API

- (void)setUpPreferences
{
    GSLogDebug(@"Loading preferences and defaults...");
    
    // Load the preferences dictionary from disk.
    _prefsDict = [[NSMutableDictionary alloc] initWithContentsOfFile:[self _getPrefsPath]];
    
    if (!_prefsDict) {
        // If preferences file doesn't exist, set the defaults.
        _prefsDict = [[NSMutableDictionary alloc] init];
        [self setDefaults];
    } else
        _prefsDict[kShouldStartAtLoginKey] = @([GSStartup existsInStartupItems]);
    
    // Ensure that application will be loaded at startup.
    if ([self shouldStartAtLogin])
        [GSStartup loadAtStartup:YES];
    
    // Since we removed this preference from v2.2 prematurely, some new users
    // might not have had it set in their defaults. If the key doesn't exist in
    // the prefs dictionary, default this sucker to enabled, because
    // notifications are helpful.
    if (_prefsDict[kShouldDisplayNotificationsKey] == nil)
        _prefsDict[kShouldDisplayNotificationsKey] = @YES;
}

- (void)setDefaults
{
    GSLogDebug(@"Setting initial defaults...");
    
    _prefsDict[kShouldCheckForUpdatesOnStartupKey] = @YES;
    _prefsDict[kShouldStartAtLoginKey] = @YES;
    _prefsDict[kShouldDisplayNotificationsKey] = @YES;
    _prefsDict[kShouldUsePowerSourceBasedSwitchingKey] = @NO;
    _prefsDict[kShouldUseSmartMenuBarIconsKey] = @NO;
    
    _prefsDict[kPowerSourceBasedSwitchingBatteryMode] = @(GSPowerSourceBasedSwitchingModeIntegrated);
    if ([GSGPU isLegacyMachine])
        _prefsDict[kPowerSourceBasedSwitchingACMode] = @(GSPowerSourceBasedSwitchingModeDiscrete);
    else
        _prefsDict[kPowerSourceBasedSwitchingACMode] = @(GSPowerSourceBasedSwitchingModeDynamic);
    
    [self savePreferences];
}

- (void)savePreferences
{
    GSLogDebug(@"Writing preferences to disk...");
    
    if ([_prefsDict writeToFile:[self _getPrefsPath] atomically:YES])
        GSLogDebug(@"Successfully wrote preferences to disk.");
    else
        GSLogDebug(@"Failed to write preferences to disk. Permissions problem in ~/Library/Preferences?");
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

- (BOOL)shouldDisplayNotifications
{
    return [_prefsDict[kShouldDisplayNotificationsKey] boolValue];
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

- (GSPowerSourceBasedSwitchingMode)modeForACAdapter
{
    return [_prefsDict[kPowerSourceBasedSwitchingACMode] intValue];
}

- (GSPowerSourceBasedSwitchingMode)modeForBattery
{
    return [_prefsDict[kPowerSourceBasedSwitchingBatteryMode] intValue];
}

#pragma mark - NSWindowDelegate protocol

- (void)windowWillClose:(NSNotification *)notification
{
    [self savePreferences];
}

@end

#pragma mark - Private helpers

@implementation GSPreferences (Internal)

- (NSString *)_getPrefsPath
{
    return kPreferencesPlistPath;
}

@end
