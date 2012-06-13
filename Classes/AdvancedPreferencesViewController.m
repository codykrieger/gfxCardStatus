//
//  AdvancedPreferencesViewController.m
//  gfxCardStatus
//
//  Created by Michal Vančo on 7/11/11.
//  Copyright 2011 Michal Vančo. All rights reserved.
//

#import "AdvancedPreferencesViewController.h"
#import "GSState.h"

@implementation AdvancedPreferencesViewController

@synthesize prefs;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:@"AdvancedPreferencesView" bundle:nil];
    if (self) {
        prefs = [PrefsController sharedInstance];
    }
    
    return self;
}

- (void)loadView {
    [super loadView];
    
    NSArray *localizedButtons = [[NSArray alloc] initWithObjects:prefChkRestoreState, prefChkPowerSourceBasedSwitching, nil];
    for (NSButton *loc in localizedButtons) {
        [loc setTitle:Str([loc title])];
    }
    
    NSArray *localizedLabels = [[NSArray alloc] initWithObjects:onBatteryTextField, pluggedInTextField, nil];
    for (NSTextField *field in localizedLabels) {
        [field setStringValue:Str([field stringValue])];
    }
    
    if ([[GSState sharedInstance] usingLegacy]) {
        [prefSegOnBattery setSegmentCount:2];
        [prefSegOnAc setSegmentCount:2];
    } else {
        [prefSegOnBattery setLabel:Str(@"Dynamic") forSegment:2];
        [prefSegOnAc setLabel:Str(@"Dynamic") forSegment:2];
    }
    
    [prefSegOnBattery setLabel:Str(@"Integrated") forSegment:0];
    [prefSegOnBattery setLabel:Str(@"Discrete") forSegment:1];
    [prefSegOnAc setLabel:Str(@"Integrated") forSegment:0];
    [prefSegOnAc setLabel:Str(@"Discrete") forSegment:1];
    
    // fit labels after localization
    [prefSegOnAc sizeToFit];
    [prefSegOnBattery sizeToFit];
}

- (NSString *)title {
    return Str(@"Advanced");
}

- (NSString *)identifier {
    return @"advanced";
}

- (NSImage *)image {
    return [NSImage imageNamed:NSImageNameAdvanced];
}

@end
