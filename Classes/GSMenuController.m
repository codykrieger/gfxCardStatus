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
#import "GSProcess.h"
#import "GSGPU.h"

#import <ReactiveCocoa/ReactiveCocoa.h>

#define kImageIconIntegratedName    @"integrated"
#define kImageIconDiscreteName      @"discrete"
#define kImageIconOpenSuffix        @"-white"

#define kShouldUseSmartMenuBarIconsKeyPath @"prefsDict.shouldUseSmartMenuBarIcons"

@interface GSMenuController (Internal)
- (void)_localizeMenu;
- (void)_updateProcessList;
- (void)_updateMenuBarIconText:(BOOL)isUsingIntegrated cardString:(NSString *)cardString;
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
    if (!(self = [super init]))
        return nil;
    
    _prefs = [GSPreferences sharedInstance];
    
    [[_prefs rac_subscribableForKeyPath:kShouldUseSmartMenuBarIconsKeyPath onObject:self] subscribeNext:^(id x) {
        GTMLoggerDebug(@"Use smart menu bar icons value changed: %@", x);
        [self updateMenu];
    }];
    
    return self;
}

#pragma mark - GSMenuController API

- (void)setupMenu
{
    [statusMenu setDelegate:self];
    
    _statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    [_statusItem setMenu:statusMenu];
    [_statusItem setHighlightMode:YES];
    
    BOOL isLegacyMachine = [GSGPU isLegacyMachine];
    [switchGPUs setHidden:!isLegacyMachine];
    [integratedOnly setHidden:isLegacyMachine];
    [discreteOnly setHidden:isLegacyMachine];
    [dynamicSwitching setHidden:isLegacyMachine];
    
    // Listen for when the menu opens and change the icons appropriately if the
    // user is using images.
    [RACAbleSelf(self.menuIsOpen) subscribeNext:^(id x) {
        GTMLoggerDebug(@"Menu open: %@", x);
        
        if (_prefs.shouldUseImageIcons) {
            NSString *imageName = _statusItem.image.name;
            
            if ([x boolValue])
                imageName = [imageName stringByAppendingString:kImageIconOpenSuffix];
            else
                imageName = [imageName stringByReplacingOccurrencesOfString:kImageIconOpenSuffix withString:@""];
            
            [_statusItem setImage:[NSImage imageNamed:imageName]];
        }
    }];
    
    [self _localizeMenu];
    [self updateMenu];
}

- (void)updateMenu
{
    GTMLoggerDebug(@"Updating status...");
    
    BOOL isUsingIntegrated = [GSMux isUsingIntegratedGPU];
    
    // get updated GPU string
    NSString *cardString = (isUsingIntegrated ? [GSGPU integratedGPUName] : [GSGPU discreteGPUName]);
    
    // set menu bar icon
    if ([_prefs shouldUseImageIcons])
        [_statusItem setImage:[NSImage imageNamed:(isUsingIntegrated ? kImageIconIntegratedName : kImageIconDiscreteName)]];
    else
        [self _updateMenuBarIconText:isUsingIntegrated cardString:cardString];
    
    if (![GSGPU isLegacyMachine]) {
        BOOL dynamic = [GSMux isUsingDynamicSwitching];
        BOOL oldStyleSwitchPolicy = [GSMux isUsingOldStyleSwitchPolicy];
        
        GTMLoggerInfo(@"Using dynamic switching?: %d", dynamic);
        GTMLoggerInfo(@"Using old-style switching policy?: %d", oldStyleSwitchPolicy);
        
        [integratedOnly setState:(oldStyleSwitchPolicy && isUsingIntegrated) ? NSOnState : NSOffState];
        [discreteOnly setState:(oldStyleSwitchPolicy && !isUsingIntegrated) ? NSOnState : NSOffState];
        [dynamicSwitching setState:(dynamic && !oldStyleSwitchPolicy) ? NSOnState : NSOffState];
    }
    
    [currentCard setTitle:[Str(@"Card") stringByReplacingOccurrencesOfString:@"%%" withString:cardString]];
    
    if (isUsingIntegrated)
        GTMLoggerInfo(@"%@ in use. Sweet deal! More battery life.", [GSGPU integratedGPUName]);
    else
        GTMLoggerInfo(@"%@ in use. Bummer! Less battery life for you.", [GSGPU discreteGPUName]);
    
    if (![GSGPU isLegacyMachine] && !isUsingIntegrated)
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
    if (!_preferencesWindowController) {
        _preferencesWindowController = [[PreferencesWindowController alloc] init];
        
        NSArray *modules = [NSArray arrayWithObjects:
                            [[GeneralPreferencesViewController alloc] init], 
                            [[AdvancedPreferencesViewController alloc] init],
                            nil];
        
        [_preferencesWindowController setModules:modules];
    }
    
    [_preferencesWindowController.window center];
    [_preferencesWindowController.window makeKeyAndOrderFront:self];
    [_preferencesWindowController.window setOrderedIndex:0];
    [NSApp activateIgnoringOtherApps:YES];
}

- (IBAction)openApplicationURL:(id)sender
{
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:kApplicationWebsiteURL]];
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
        [GSMux setMode:GSSwitcherModeToggleGPU];
        return;
    }
    
    // current cards
    if ([sender state] == NSOnState) return;
    
    BOOL retval = NO;
    if (sender == integratedOnly) {
        GTMLoggerInfo(@"Setting Integrated only...");
        retval = [GSMux setMode:GSSwitcherModeForceIntegrated];
    }
    if (sender == discreteOnly) { 
        GTMLoggerInfo(@"Setting Discrete only...");
        retval = [GSMux setMode:GSSwitcherModeForceDiscrete];
    }
    if (sender == dynamicSwitching) {
        GTMLoggerInfo(@"Setting dynamic switching...");
        retval = [GSMux setMode:GSSwitcherModeDynamicSwitching];
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
    self.menuIsOpen = YES;
}

- (void)menuDidClose:(NSMenu *)menu
{
    self.menuIsOpen = NO;
}

@end

@implementation GSMenuController (Internal)

- (void)_localizeMenu
{
    NSString *version = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
    [versionItem setTitle:[Str(@"About") stringByReplacingOccurrencesOfString:@"%%" withString:version]];
    NSArray *localized = [NSArray arrayWithObjects:updateItem, preferencesItem,
                          quitItem, switchGPUs, integratedOnly, discreteOnly, 
                          dynamicSwitching, dependentProcesses, processList, 
                          nil];
    for (NSButton *loc in localized)
        [loc setTitle:Str([loc title])];
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

- (void)_updateMenuBarIconText:(BOOL)isUsingIntegrated cardString:(NSString *)cardString
{
    // grab first character of GPU string for the menu bar icon
    unichar firstLetter;
    
    if ([GSGPU isLegacyMachine] || ![_prefs shouldUseSmartMenuBarIcons]) {
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
    [_statusItem setAttributedTitle:title];
}

@end
