//
//  GSMenuController.m
//  gfxCardStatus
//
//  Created by Cody Krieger on 6/12/12.
//  Copyright (c) 2012 Cody Krieger. All rights reserved.
//

#import <ReactiveCocoa/ReactiveCocoa.h>

#import "GSMenuController.h"
#import "GeneralPreferencesViewController.h"
#import "AdvancedPreferencesViewController.h"
#import "GSMux.h"
#import "GSProcess.h"
#import "GSGPU.h"

@interface GSMenuController ()
@property BOOL menuIsOpen;
- (void)_localizeMenu;
- (void)_updateProcessList;
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

@synthesize menuIsOpen;

#pragma mark - Initializers

- (id)init
{
    self = [super init];
    if (self) {
        prefs = [PrefsController sharedInstance];
        
        // FIXME: Test out ReactiveCocoa for this use case.
        [RACAble(prefs, shouldUseSmartMenuBarIcons) subscribeNext:^(id smartIcons) {
            GTMLoggerDebug(@"shouldUseSmartMenuBarIcons: %d", [smartIcons boolValue]);
            [self updateMenu];
        }];
    }
    
    return self;
}

#pragma mark - GSMenuController API

- (void)setupMenu
{
    [statusMenu setDelegate:self];
    
    statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    [statusItem setMenu:statusMenu];
    [statusItem setHighlightMode:YES];
    
    BOOL isLegacyMachine = [GSGPU isLegacyMachine];
    [switchGPUs setHidden:!isLegacyMachine];
    [integratedOnly setHidden:isLegacyMachine];
    [discreteOnly setHidden:isLegacyMachine];
    [dynamicSwitching setHidden:isLegacyMachine];
    
    // FIXME: Test out ReactiveCocoa for this use case.
    [RACAbleSelf(self.menuIsOpen) subscribeNext:^(id open) {
        GTMLoggerDebug(@"open: %d", [open boolValue]);
    }];
    
    [self _localizeMenu];
    [self updateMenu];
}

- (void)updateMenu
{
    // FIXME: Refactor this whole method.
    
    GTMLoggerDebug(@"Updating status...");
    
    BOOL isUsingIntegrated = [GSMux isUsingIntegratedGPU];
    
    // get updated GPU string
    NSString *cardString = (isUsingIntegrated ? [GSGPU integratedGPUName] : [GSGPU discreteGPUName]);
    
    // set menu bar icon
    if ([prefs shouldUseImageIcons]) {
        [statusItem setImage:[NSImage imageNamed:(isUsingIntegrated ? @"integrated.png" : @"discrete.png")]];
    } else {
        // grab first character of GPU string for the menu bar icon
        unichar firstLetter;
        
        if ([GSGPU isLegacyMachine] || ![prefs shouldUseSmartMenuBarIcons]) {
            firstLetter = [GSMux isUsingIntegratedGPU] ? 'i' : 'd';
        } else {
            firstLetter = [cardString characterAtIndex:0];
        }
        
        // format firstLetter into an NSString *
        NSString *letter = [[NSString stringWithFormat:@"%C", firstLetter] lowercaseString];
        int fontSize = ([letter isEqualToString:@"n"] || [letter isEqualToString:@"a"] ? 19 : 18);
        
        // set the correct font
        NSFontManager *fontManager = [NSFontManager sharedFontManager];
        NSFont *boldItalic = [fontManager fontWithFamily:@"Georgia"
                                                  traits:NSBoldFontMask|NSItalicFontMask
                                                  weight:0
                                                    size:fontSize];
        
        // create NSAttributedString with font
        NSDictionary *attributes = [[NSDictionary alloc] initWithObjectsAndKeys:
                                    boldItalic, NSFontAttributeName, 
                                    [NSNumber numberWithDouble:2.0], NSBaselineOffsetAttributeName, nil];
        NSAttributedString *title = [[NSAttributedString alloc] 
                                     initWithString:letter
                                     attributes:attributes];
        
        // set menu bar text "icon"
        [statusItem setAttributedTitle:title];
    }
    
    if (![GSGPU isLegacyMachine]) {
        BOOL dynamic = [GSMux isUsingDynamicSwitching];
        
        [integratedOnly setState:(!dynamic && isUsingIntegrated) ? NSOnState : NSOffState];
        [discreteOnly setState:(!dynamic && !isUsingIntegrated) ? NSOnState : NSOffState];
        [dynamicSwitching setState:dynamic ? NSOnState : NSOffState];
    }
    
    [currentCard setTitle:[Str(@"Card") stringByReplacingOccurrencesOfString:@"%%" withString:cardString]];
    
    if (isUsingIntegrated)
        GTMLoggerInfo(@"%@ in use. Sweet deal! More battery life.", [GSGPU integratedGPUName]);
    else
        GTMLoggerInfo(@"%@ in use. Bummer! Less battery life for you.", [GSGPU discreteGPUName]);
    
    if (!isUsingIntegrated)
        [self _updateProcessList];
}

#pragma mark - UI Actions

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
        [GSMux switcherSetMode:GSSwitcherModeToggleGPU];
        return;
    }
    
    // current cards
    if ([sender state] == NSOnState) return;
    
    BOOL retval = NO;
    if (sender == integratedOnly) {
        GTMLoggerInfo(@"Setting Integrated only...");
        retval = [GSMux switcherSetMode:GSSwitcherModeForceIntegrated];
    }
    if (sender == discreteOnly) { 
        GTMLoggerInfo(@"Setting Discrete only...");
        retval = [GSMux switcherSetMode:GSSwitcherModeForceDiscrete];
    }
    if (sender == dynamicSwitching) {
        GTMLoggerInfo(@"Setting dynamic switching...");
        retval = [GSMux switcherSetMode:GSSwitcherModeDynamicSwitching];
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
    [self _updateProcessList];
}

- (void)menuWillOpen:(NSMenu *)menu
{
    // FIXME: Do this in a shorter/more succinct way.
    
    // white image when menu is open
    if ([prefs shouldUseImageIcons]) {
        [statusItem setImage:[NSImage imageNamed:[[[statusItem image] name] stringByAppendingString:@"-white.png"]]];
    }
}

- (void)menuDidClose:(NSMenu *)menu
{
    // FIXME: Do this in a shorter/more succinct way.
    
    // black image when menu is closed
    if ([prefs shouldUseImageIcons]) {
        [statusItem setImage:[NSImage imageNamed:[[[statusItem image] name] stringByReplacingOccurrencesOfString:@"-white" withString:@".png"]]];
    }
}

#pragma mark - Private helpers

- (void)_localizeMenu
{
    NSString *version = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
    [versionItem setTitle:[Str(@"About") stringByReplacingOccurrencesOfString:@"%%" withString:version]];
    NSArray *localized = [NSArray arrayWithObjects:updateItem, preferencesItem,
                          quitItem, switchGPUs, integratedOnly, discreteOnly, 
                          dynamicSwitching, dependentProcesses, processList, 
                          nil];
    for (NSButton *loc in localized) {
        [loc setTitle:Str([loc title])];
    }
}

- (void)_updateProcessList
{
    // If we're using a 9400M/9600M GT model, no need to display/update the
    // dependencies list.
    if ([GSGPU isLegacyMachine])
        return;
    
    for (NSMenuItem *menuItem in [statusMenu itemArray]) {
        if ([menuItem indentationLevel] > 0 && ![menuItem isEqual:processList])
            [statusMenu removeItem:menuItem];
    }
    
    BOOL isUsingIntegrated = [GSMux isUsingIntegratedGPU];
    
    [processList setHidden:isUsingIntegrated];
    [processesSeparator setHidden:isUsingIntegrated];
    [dependentProcesses setHidden:isUsingIntegrated];
    
    // No point in updating the list if it isn't visible.
    if (isUsingIntegrated)
        return;
    
    GTMLoggerDebug(@"Updating process list...");
    
    NSArray *processes = [GSProcess getTaskList];
    
    [processList setHidden:([processes count] > 0)];
    
    for (NSDictionary *dict in processes) {
        NSString *taskName = [dict objectForKey:kTaskItemName];
        NSString *pid = [dict objectForKey:kTaskItemPID];
        NSString *title = [NSString stringWithString:taskName];
        if (![pid isEqualToString:@""])
            title = [title stringByAppendingFormat:@", PID: %@", pid];
        
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:title 
                                                      action:nil 
                                               keyEquivalent:@""];
        [item setIndentationLevel:1];
        [statusMenu insertItem:item 
                       atIndex:([statusMenu indexOfItem:processList] + 1)];
    }
}

@end
