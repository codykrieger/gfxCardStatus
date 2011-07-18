//
//  GeneralPreferencesViewController.m
//  gfxCardStatus
//
//  Created by Michal Vančo on 7/11/11.
//  Copyright 2011 Michal Vančo. All rights reserved.
//

#import "GeneralPreferencesViewController.h"
#import "PrefsController.h"

@interface GeneralPreferencesViewController ()
@property (assign) PrefsController *prefs;
@end

@implementation GeneralPreferencesViewController

@synthesize prefs;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:@"GeneralPreferencesView" bundle:nil];
    if (self) {
        prefs = [PrefsController sharedInstance];
    }
    return self;
}

- (void)dealloc {
    [prefs removeObserver:self forKeyPath:@"prefs.shouldStartAtLogin"];
    
    [super dealloc];
}

- (void)loadView {
    [super loadView];
    
    [prefs addObserver:self forKeyPath:@"prefs.shouldStartAtLogin" options:NSKeyValueObservingOptionNew context:nil];
    
    NSArray *localizedButtons = [[NSArray alloc] initWithObjects:prefChkGrowl, prefChkStartup, prefChkUpdate, nil];
    for (NSButton *loc in localizedButtons) {
        [loc setTitle:Str([loc title])];
    }
    [localizedButtons release];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString:@"prefs.shouldStartAtLogin"]) {
        [prefs loadAtStartup:([prefChkStartup state] ? YES : NO)];
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
