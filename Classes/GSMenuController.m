//
//  GSMenuController.m
//  gfxCardStatus
//
//  Created by Cody Krieger on 6/12/12.
//  Copyright (c) 2012 Cody Krieger. All rights reserved.
//

#import "GSMenuController.h"
#import "GeneralPreferencesViewController.h"
#import "AdvancedPreferencesViewController.h"
#import "GSMux.h"

@interface GSMenuController ()
- (void)localizeMenu;
@end

@implementation GSMenuController

@synthesize delegate;

@synthesize statusMenu;

@synthesize versionItem;
@synthesize updateItem;
@synthesize preferencesItem;
@synthesize quitItem;
@synthesize currentCard;
@synthesize currentPowerSource;
@synthesize switchGPUs;
@synthesize integratedOnly;
@synthesize discreteOnly;
@synthesize dynamicSwitching;
@synthesize processesSeparator;
@synthesize dependentProcesses;
@synthesize processList;

- (void)setupMenu
{
    [statusMenu setDelegate:self];
    statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    [statusItem setMenu:statusMenu];
    [statusItem setHighlightMode:YES];
    
    [self localizeMenu];
}

- (IBAction)openAbout:(id)sender
{
    [[NSApplication sharedApplication] orderFrontStandardAboutPanel:nil];
    [NSApp activateIgnoringOtherApps:YES];
}

- (IBAction)openPreferences:(id)sender
{
    if (!preferencesWindowController) {
        preferencesWindowController = [[PreferencesWindowController alloc] init];
        
        NSArray *modules = [NSArray arrayWithObjects:
                            [[GeneralPreferencesViewController alloc] init], 
                            [[AdvancedPreferencesViewController alloc] init],
                            nil];
        
        [preferencesWindowController setModules:modules];
    }
    
    // FIXME this sucks, the menu controller shouldn't know anything about prefs
    preferencesWindowController.window.delegate = prefs;
    
    [preferencesWindowController.window center];
    [preferencesWindowController.window makeKeyAndOrderFront:self];
    [preferencesWindowController.window setOrderedIndex:0];
    [NSApp activateIgnoringOtherApps:YES];
}

- (IBAction)openApplicationURL:(id)sender
{
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://codykrieger.com/gfxCardStatus"]];
}

- (IBAction)quit:(id)sender
{
    [[NSApplication sharedApplication] terminate:self];
}

- (IBAction)setMode:(id)sender
{
    // legacy cards
    if (sender == switchGPUs) {
        GTMLoggerInfo(@"Switching GPUs...");
        [GSMux switcherSetMode:modeToggleGPU];
        return;
    }
    
    // current cards
    if ([sender state] == NSOnState) return;
    
    BOOL retval = NO;
    if (sender == integratedOnly) {
        GTMLoggerInfo(@"Setting Integrated only...");
        retval = [GSMux switcherSetMode:modeForceIntegrated];
    }
    if (sender == discreteOnly) { 
        GTMLoggerInfo(@"Setting Discrete only...");
        retval = [GSMux switcherSetMode:modeForceDiscrete];
    }
    if (sender == dynamicSwitching) {
        GTMLoggerInfo(@"Setting dynamic switching...");
        retval = [GSMux switcherSetMode:modeDynamicSwitching];
    }
    
    // only change status in case of success
    if (retval) {
        [integratedOnly setState:(sender == integratedOnly ? NSOnState : NSOffState)];
        [discreteOnly setState:(sender == discreteOnly ? NSOnState : NSOffState)];
        [dynamicSwitching setState:(sender == dynamicSwitching ? NSOnState : NSOffState)];
    }
}

#pragma mark - NSMenuDelegate protocol

- (void)menuNeedsUpdate:(NSMenu *)menu
{
    
}

- (void)menuWillOpen:(NSMenu *)menu
{
    
}

- (void)menuDidClose:(NSMenu *)menu
{
    
}

#pragma mark - Private helpers

- (void)localizeMenu
{
    NSString *version = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
    [versionItem setTitle:[Str(@"About") stringByReplacingOccurrencesOfString:@"%%" withString:version]];
    NSArray *localized = [[NSArray alloc] initWithObjects:updateItem, preferencesItem, quitItem, switchGPUs, integratedOnly, 
                          discreteOnly, dynamicSwitching, dependentProcesses, processList, nil];
    for (NSButton *loc in localized) {
        [loc setTitle:Str([loc title])];
    }
}

@end
