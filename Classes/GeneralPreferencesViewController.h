//
//  GeneralPreferencesViewController.h
//  gfxCardStatus
//
//  Created by Michal Vančo on 7/11/11.
//  Copyright 2011 Michal Vančo. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "GSPreferencesModule.h"
#import "GSPreferences.h"

@interface GeneralPreferencesViewController : NSViewController <GSPreferencesModule>

@property (strong) IBOutlet NSButton *prefChkSmartIcons; // use first letter of GPU to determine icon

@property (strong) IBOutlet NSButton *prefChkUpdate; // check for updates on startup
@property (strong) IBOutlet NSButton *prefChkStartup; // start at login

@property (strong) GSPreferences *prefs;

@end
