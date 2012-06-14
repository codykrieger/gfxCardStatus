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

- (BOOL)shouldCheckForUpdatesOnStartup;
- (BOOL)shouldStartAtLogin;
- (BOOL)shouldUsePowerSourceBasedSwitching;
- (BOOL)shouldUseImageIcons;
- (BOOL)shouldUseSmartMenuBarIcons;
- (int)modeForPowerSource:(NSString *)powerSource;

- (void)setBool:(BOOL)value forKey:(NSString *)key;
- (BOOL)boolForKey:(NSString *)key;

- (void)savePreferences;

+ (PrefsController *)sharedInstance;

@end
