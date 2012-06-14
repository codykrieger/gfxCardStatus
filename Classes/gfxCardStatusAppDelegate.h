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
    IBOutlet NSMenu *statusMenu;
    
    // dynamic menu items - these change
    IBOutlet NSMenuItem *versionItem;
    IBOutlet NSMenuItem *updateItem;
    IBOutlet NSMenuItem *preferencesItem;
    IBOutlet NSMenuItem *quitItem;

    IBOutlet NSMenuItem *currentCard;
    IBOutlet NSMenuItem *currentPowerSource;
    IBOutlet NSMenuItem *switchGPUs;
    IBOutlet NSMenuItem *integratedOnly;
    IBOutlet NSMenuItem *discreteOnly;
    IBOutlet NSMenuItem *dynamicSwitching;
    
    // process list menu items
    IBOutlet NSMenuItem *processesSeparator;
    IBOutlet NSMenuItem *dependentProcesses;
    IBOutlet NSMenuItem *processList;
    
    // preferences for all!
    PrefsController *prefs;
    PreferencesWindowController *pwc;
    
    // state for all!!!
    GSState *state;
    
    // power source monitor
//    PowerSourceMonitor *powerSourceMonitor;
//    PowerSource lastPowerSource;
}

@property (strong) IBOutlet GSMenuController *menuController;

@end
