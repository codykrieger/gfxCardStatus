//
//  GSMenuController.h
//  gfxCardStatus
//
//  Created by Cody Krieger on 6/12/12.
//  Copyright (c) 2012 Cody Krieger. All rights reserved.
//

#import "PreferencesWindowController.h"
#import "GSPreferences.h"

@protocol GSMenuControllerDelegate <NSObject>
- (void)something;
@end

@interface GSMenuController : NSObject <NSMenuDelegate> {
    NSStatusItem *_statusItem;
    
    GSPreferences *_prefs;
    PreferencesWindowController *_preferencesWindowController;
}

@property (unsafe_unretained) id<GSMenuControllerDelegate> delegate;

// the menu
@property (strong) IBOutlet NSMenu *statusMenu;

// dynamic menu items - these change
@property (weak) IBOutlet NSMenuItem *versionItem;
@property (weak) IBOutlet NSMenuItem *updateItem;
@property (weak) IBOutlet NSMenuItem *preferencesItem;
@property (weak) IBOutlet NSMenuItem *quitItem;
@property (weak) IBOutlet NSMenuItem *visitWebsiteItem;

@property (weak) IBOutlet NSMenuItem *currentCard;
@property (weak) IBOutlet NSMenuItem *currentPowerSource;
@property (weak) IBOutlet NSMenuItem *switchGPUs;
@property (weak) IBOutlet NSMenuItem *integratedOnly;
@property (weak) IBOutlet NSMenuItem *discreteOnly;
@property (weak) IBOutlet NSMenuItem *dynamicSwitching;

// process list menu items
@property (weak) IBOutlet NSMenuItem *processesSeparator;
@property (weak) IBOutlet NSMenuItem *dependentProcesses;
@property (weak) IBOutlet NSMenuItem *processList;

@property BOOL menuIsOpen;

- (void)setupMenu;
- (void)updateMenu;

- (IBAction)openAbout:(id)sender;
- (IBAction)openPreferences:(id)sender;
- (IBAction)openApplicationURL:(id)sender;
- (IBAction)killProcess:(id)sender;
- (IBAction)quit:(id)sender;

- (IBAction)setMode:(id)sender;

@end
