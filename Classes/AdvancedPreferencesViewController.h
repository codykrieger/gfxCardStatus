//
//  AdvancedPreferencesViewController.h
//  gfxCardStatus
//
//  Created by Michal Vančo on 7/11/11.
//  Copyright 2011 Michal Vančo. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "GSPreferencesModule.h"
#import "GSPreferences.h"

@interface AdvancedPreferencesViewController : NSViewController <GSPreferencesModule>

@property (strong) GSPreferences *prefs;

- (IBAction)whyButtonClicked:(id)sender;

@end
