//
//  AdvancedPreferencesViewController.h
//  gfxCardStatus
//
//  Created by Michal Vančo on 7/11/11.
//  Copyright 2011 Michal Vančo. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "PreferencesModule.h"

@interface AdvancedPreferencesViewController : NSViewController <PreferencesModule> {
@private
    IBOutlet NSButton *prefChkRestoreState; // restore last used mode on startup
    IBOutlet NSButton *prefChkPowerSourceBasedSwitching; // use power source-based switching
    IBOutlet NSSegmentedControl *prefSegOnBattery; // pref for gpu on battery
    IBOutlet NSSegmentedControl *prefSegOnAc; // pref for gpu on ac
    IBOutlet NSTextField *onBatteryTextField;
    IBOutlet NSTextField *pluggedInTextField;
    
    PrefsController *prefs;
}

@end
