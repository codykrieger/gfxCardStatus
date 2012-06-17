//
//  gfxCardStatusAppDelegate.h
//  gfxCardStatus
//
//  Created by Cody Krieger on 4/22/10.
//  Copyright 2010 Cody Krieger. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Sparkle/Sparkle.h>
#import <Sparkle/SUUpdater.h>

#import "PrefsController.h"
#import "PreferencesWindowController.h"
#import "GSState.h"
#import "GSMenuController.h"
#import "GSGPU.h"

@interface gfxCardStatusAppDelegate : NSObject <NSApplicationDelegate,GSGPUDelegate> {
    NSStatusItem *statusItem;
    
    IBOutlet SUUpdater *updater;
    
    // preferences for all!
    PrefsController *prefs;
    PreferencesWindowController *pwc;
    
    // power source monitor
//    PowerSourceMonitor *powerSourceMonitor;
//    PowerSource lastPowerSource;
}

@property (strong) IBOutlet GSMenuController *menuController;

@end
