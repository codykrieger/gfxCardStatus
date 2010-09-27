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
    IBOutlet NSButton *prefChkLog; // log diagnostic messages to console
    
    // switching preferences
    IBOutlet NSButton *prefChkRestoreState; // restore last used mode on startup
    IBOutlet NSButton *prefChkPowerSourceBasedSwitching; // use power source-based switching
    IBOutlet NSSegmentedControl *prefSegOnBattery; // pref for gpu on battery
    IBOutlet NSSegmentedControl *prefSegOnAc; // pref for gpu on ac
    
    NSNumber *yesNumber;
    NSNumber *noNumber;
}

- (void)setDefaults;
- (void)savePreferences;
- (BOOL)existsInStartupItems;
- (void)loadAtStartup:(BOOL)value;

- (BOOL)shouldCheckForUpdatesOnStartup;
- (BOOL)shouldGrowl;
- (BOOL)shouldStartAtLogin;
- (BOOL)shouldLogToConsole;
- (BOOL)shouldRestoreStateOnStartup;
- (BOOL)shouldUsePowerSourceBasedSwitching;
- (int)shouldRestoreToMode;

- (void)setLastMode:(int)value;

- (IBAction)preferenceChanged:(id)sender;

+ (PrefsController *)sharedInstance;

@end
