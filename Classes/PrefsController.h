//
//  PrefsController.h
//  gfxCardStatus
//
//  Created by Cody Krieger on 9/26/10.
//  Copyright 2010 Cody Krieger. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface PrefsController : NSWindowController <NSWindowDelegate> {
    NSString *prefsPath;
    NSMutableDictionary *prefs;
    
    // general preferences
    IBOutlet NSButton *prefChkUpdate; // check for updates on startup
    IBOutlet NSButton *prefChkGrowl; // use growl to send notifications
    IBOutlet NSButton *prefChkStartup; // start at login
    
    // switching preferences
    IBOutlet NSButton *prefChkRestoreState; // restore last used mode on startup
    IBOutlet NSButton *prefChkPowerSourceBasedSwitching; // use power source-based switching
    IBOutlet NSSegmentedControl *prefSegOnBattery; // pref for gpu on battery
    IBOutlet NSSegmentedControl *prefSegOnAc; // pref for gpu on ac
    
    // labels
    IBOutlet NSTextField *onBatteryTextField;
    IBOutlet NSTextField *pluggedInTextField;
    
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

- (void)setControlsToPreferences;
- (void)savePreferences;
- (void)openPreferences;

- (IBAction)preferenceChanged:(id)sender;

+ (PrefsController *)sharedInstance;

@end
