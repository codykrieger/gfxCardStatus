//
//  GeneralPreferencesViewController.m
//  gfxCardStatus
//
//  Created by Michal Vančo on 7/11/11.
//  Copyright 2011 Michal Vančo. All rights reserved.
//

#import "GeneralPreferencesViewController.h"
#import "PrefsController.h"
#import "SessionMagic.h"
#import "GSStartup.h"

@implementation GeneralPreferencesViewController

@synthesize prefs;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:@"GeneralPreferencesView" bundle:nil];
    if (self) {
        prefs = [PrefsController sharedInstance];
    }
    return self;
}

- (void)loadView {
    [super loadView];
    
    [prefs addObserver:self forKeyPath:@"prefs.shouldStartAtLogin" options:NSKeyValueObservingOptionNew context:nil];
    
    NSArray *localizedButtons = [[NSArray alloc] initWithObjects:prefChkStartup, prefChkUpdate, prefChkSmartIcons, nil];
    for (NSButton *loc in localizedButtons) {
        [loc setTitle:Str([loc title])];
    }
    
    SessionMagic *state = [SessionMagic sharedInstance];
    if ([state usingLegacy])
        [prefChkSmartIcons setEnabled:NO];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString:@"prefs.shouldStartAtLogin"]) {
        [GSStartup loadAtStartup:([prefChkStartup state] ? YES : NO)];
    }
}

- (NSString *)title {
    return Str(@"General");
}

- (NSString *)identifier {
    return @"general";
}

- (NSImage *)image {
    return [NSImage imageNamed:NSImageNamePreferencesGeneral];
}

@end
