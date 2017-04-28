//
//  gfxCardStatusAppDelegate.h
//  gfxCardStatus
//
//  Created by Cody Krieger on 4/22/10.
//  Copyright 2010 Cody Krieger. All rights reserved.
//

#import "GSPreferences.h"
#import "PreferencesWindowController.h"
#import "GSMenuController.h"
#import "GSGPU.h"

@import Sparkle;

@interface gfxCardStatusAppDelegate : NSObject <NSApplicationDelegate,GSGPUDelegate> {
    GSPreferences *_prefs;
}

@property (strong) IBOutlet SUUpdater *updater;
@property (strong) IBOutlet GSMenuController *menuController;

@end
