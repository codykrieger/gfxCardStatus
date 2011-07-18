//
//  PrefsController.h
//  gfxCardStatus
//
//  Created by Cody Krieger on 9/26/10.
//  Copyright 2010 Cody Krieger. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface PrefsController : NSObject <NSWindowDelegate> {
    NSString *prefsPath;
    NSMutableDictionary *prefs;
    
    NSNumber *yesNumber;
    NSNumber *noNumber;
}

- (void)setUpPreferences;
- (void)setDefaults;
- (void)savePreferences;
- (BOOL)existsInStartupItems;
- (void)loadAtStartup:(BOOL)value;
- (NSString *)getPrefsPath;

- (BOOL)shouldCheckForUpdatesOnStartup;
- (BOOL)shouldGrowl;
- (BOOL)shouldStartAtLogin;
- (BOOL)shouldRestoreStateOnStartup;
- (BOOL)shouldUsePowerSourceBasedSwitching;
- (BOOL)shouldUseImageIcons;
- (int)shouldRestoreToMode;
- (int)modeForPowerSource:(NSString *)powerSource;

- (void)setLastMode:(int)value;

- (void)setBool:(BOOL)value forKey:(NSString *)key;
- (BOOL)boolForKey:(NSString *)key;

- (void)savePreferences;

+ (PrefsController *)sharedInstance;

@end
