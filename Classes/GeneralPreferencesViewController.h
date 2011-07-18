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
    IBOutlet NSButton *prefChkUpdate; // check for updates on startup
    IBOutlet NSButton *prefChkGrowl; // use growl to send notifications
    IBOutlet NSButton *prefChkStartup; // start at login

    PrefsController *prefs;
}

@end
