//
//  GeneralPreferencesViewController.h
//  gfxCardStatus
//
//  Created by Michal Vančo on 7/11/11.
//  Copyright 2011 Michal Vančo. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "PreferencesModule.h"

@interface GeneralPreferencesViewController : NSViewController <PreferencesModule> {
@private
    IBOutlet NSButton *prefChkSmartIcons; // use first letter of GPU to determine icon
    
    IBOutlet NSButton *prefChkUpdate; // check for updates on startup
    IBOutlet NSButton *prefChkStartup; // start at login
}

@property (strong) PrefsController *prefs;

@end
