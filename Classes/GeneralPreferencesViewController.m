//
//  GeneralPreferencesViewController.m
//  gfxCardStatus
//
//  Created by Michal Vančo on 7/11/11.
//  Copyright 2011 Michal Vančo. All rights reserved.
//

#import "GeneralPreferencesViewController.h"
#import "GSPreferences.h"
#import "GSStartup.h"
#import "GSGPU.h"
#import <ReactiveCocoa/ReactiveCocoa.h>

#define kGeneralPreferencesName         @"General"

#define kShouldStartAtLoginKeyPath      @"prefsDict.shouldStartAtLogin"

@interface GeneralPreferencesViewController (Internal)
- (BOOL)isLegacyMachine;
@end

@implementation GeneralPreferencesViewController

@synthesize prefChkSmartIcons;
@synthesize prefChkUpdate;
@synthesize prefChkStartup;
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
    
    [[prefs rac_subscribableForKeyPath:kShouldStartAtLoginKeyPath onObject:self] subscribeNext:^(id x) {
        GTMLoggerDebug(@"Start at login value changed: %@", x);
        [GSStartup loadAtStartup:[x boolValue]];
    }];
    
    NSArray *localizedButtons = [[NSArray alloc] initWithObjects:prefChkStartup, prefChkUpdate, prefChkSmartIcons, nil];
    for (NSButton *loc in localizedButtons) {
        [loc setTitle:Str([loc title])];
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
