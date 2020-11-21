//
//  GSPreferences.h
//  gfxCardStatus
//
//  Created by Cody Krieger on 9/26/10.
//  Copyright 2010 Cody Krieger. All rights reserved.
//

#import <Cocoa/Cocoa.h>

typedef enum {
    GSPowerSourceBasedSwitchingModeIntegrated = 0,
    GSPowerSourceBasedSwitchingModeDiscrete = 1,
    GSPowerSourceBasedSwitchingModeDynamic = 2
} GSPowerSourceBasedSwitchingMode;

@interface GSPreferences : NSObject <NSWindowDelegate> {
    NSMutableDictionary *_prefsDict;
    
    NSNumber *yesNumber;
    NSNumber *noNumber;
}

@property (strong) NSMutableDictionary *prefsDict;

- (void)setUpPreferences;
- (void)setDefaults;
- (void)savePreferences;

- (BOOL)shouldCheckForUpdatesOnStartup;
- (BOOL)shouldStartAtLogin;
- (BOOL)shouldDisplayNotifications;
- (BOOL)shouldUsePowerSourceBasedSwitching;
- (BOOL)shouldUseSmartMenuBarIcons;
- (GSPowerSourceBasedSwitchingMode)modeForACAdapter;
- (GSPowerSourceBasedSwitchingMode)modeForBattery;

- (void)setBool:(BOOL)value forKey:(NSString *)key;
- (BOOL)boolForKey:(NSString *)key;

+ (GSPreferences *)sharedInstance;

@end
