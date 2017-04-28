//
//  GeneralPreferencesViewController.m
//  gfxCardStatus
//
//  Created by Michal Vančo on 7/11/11.
//  Copyright 2011 Michal Vančo. All rights reserved.
//

#import "GeneralPreferencesViewController.h"
#import "GSNotifier.h"
#import "GSPreferences.h"
#import "GSStartup.h"
#import "GSGPU.h"
@import ReactiveObjC;

#define kGeneralPreferencesName         @"General"

#define kShouldStartAtLoginKeyPath      @"prefsDict.shouldStartAtLogin"

@interface GeneralPreferencesViewController (Internal)
- (BOOL)isLegacyMachine;
@end

@implementation GeneralPreferencesViewController

@synthesize prefChkSmartIcons;
@synthesize prefChkUpdate;
@synthesize prefChkStartup;
@synthesize prefChkGrowl;
@synthesize prefs;

#pragma mark - Initializers

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    if (!(self = [super initWithNibName:@"GeneralPreferencesView" bundle:nil]))
        return nil;
    
    prefs = [GSPreferences sharedInstance];
    
    return self;
}

#pragma mark - Overrides

- (void)loadView
{
    [super loadView];
    
    // Add or remove the app from the current user's Login Items upon hearing
    // from our awesome friend Josh Abernathy at GitHub that the value we're
    // subscribed to has changed.
    
    [[prefs rac_valuesForKeyPath:kShouldStartAtLoginKeyPath observer: self] subscribeNext:^(id x) {
        GTMLoggerDebug(@"Start at login value changed: %@", x);
        [GSStartup loadAtStartup:[x boolValue]];
    }];
    
    NSArray *localizedButtons = [[NSArray alloc] initWithObjects:prefChkStartup, prefChkUpdate, prefChkSmartIcons, prefChkGrowl, nil];
    for (NSButton *loc in localizedButtons)
        [loc setTitle:Str([loc title])];

    if ([GSNotifier notificationCenterIsAvailable]) {
        [prefChkGrowl setHidden:YES];

        NSRect frame = self.view.frame;
        frame.size.height -= NSHeight(prefChkGrowl.frame);
        frame.origin.y -= NSHeight(prefChkGrowl.frame);
        self.view.frame = frame;
    }
}

#pragma mark - Passthrough properties

- (BOOL)isLegacyMachine
{
    return [GSGPU isLegacyMachine];
}

#pragma mark - GSPreferencesModule protocol

- (NSString *)title
{
    return Str(kGeneralPreferencesName);
}

- (NSString *)identifier
{
    return kGeneralPreferencesName;
}

- (NSImage *)image
{
    return [NSImage imageNamed:NSImageNamePreferencesGeneral];
}

@end
