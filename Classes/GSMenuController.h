//
//  GSMenuController.h
//  gfxCardStatus
//
//  Created by Cody Krieger on 6/12/12.
//  Copyright (c) 2012 Cody Krieger. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "PreferencesWindowController.h"

@protocol GSMenuControllerDelegate <NSObject>
- (void)something;
@end

@interface GSMenuController : NSObject <NSMenuDelegate> {
    NSStatusItem *statusItem;
    
    PrefsController *prefs;
    PreferencesWindowController *preferencesWindowController;
}

@property (unsafe_unretained) id<GSMenuControllerDelegate> delegate;

// the menu
@property (strong) IBOutlet NSMenu *statusMenu;

// dynamic menu items - these change
@property (strong) IBOutlet NSMenuItem *versionItem;
@property (strong) IBOutlet NSMenuItem *updateItem;
@property (strong) IBOutlet NSMenuItem *preferencesItem;
@property (strong) IBOutlet NSMenuItem *quitItem;

@property (strong) IBOutlet NSMenuItem *currentCard;
@property (strong) IBOutlet NSMenuItem *currentPowerSource;
@property (strong) IBOutlet NSMenuItem *switchGPUs;
@property (strong) IBOutlet NSMenuItem *integratedOnly;
@property (strong) IBOutlet NSMenuItem *discreteOnly;
@property (strong) IBOutlet NSMenuItem *dynamicSwitching;

// process list menu items
@property (strong) IBOutlet NSMenuItem *processesSeparator;
@property (strong) IBOutlet NSMenuItem *dependentProcesses;
@property (strong) IBOutlet NSMenuItem *processList;

- (void)setupMenu;

- (IBAction)openAbout:(id)sender;
- (IBAction)openPreferences:(id)sender;
- (IBAction)openApplicationURL:(id)sender;
- (IBAction)quit:(id)sender;

- (IBAction)setMode:(id)sender;

@end
