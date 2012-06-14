//
//  AdvancedPreferencesViewController.h
//  gfxCardStatus
//
//  Created by Michal Vančo on 7/11/11.
//  Copyright 2011 Michal Vančo. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "GSPreferencesModule.h"
#import "PrefsController.h"

@interface AdvancedPreferencesViewController : NSViewController <GSPreferencesModule>

@property (strong) IBOutlet NSButton *prefChkRestoreState; // restore last used mode on startup
@property (strong) IBOutlet NSButton *prefChkPowerSourceBasedSwitching; // use power source-based switching
@property (strong) IBOutlet NSSegmentedControl *prefSegOnBattery; // pref for gpu on battery
@property (strong) IBOutlet NSSegmentedControl *prefSegOnAc; // pref for gpu on ac
@property (strong) IBOutlet NSTextField *onBatteryTextField;
@property (strong) IBOutlet NSTextField *pluggedInTextField;

@property (strong) PrefsController *prefs;

@end
