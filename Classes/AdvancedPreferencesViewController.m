//
//  AdvancedPreferencesViewController.m
//  gfxCardStatus
//
//  Created by Michal Vančo on 7/11/11.
//  Copyright 2011 Michal Vančo. All rights reserved.
//

#import "AdvancedPreferencesViewController.h"
#import "GSGPU.h"

#define kAdvancedPreferencesName        @"Advanced"

@implementation AdvancedPreferencesViewController

@synthesize prefChkPowerSourceBasedSwitching;
@synthesize prefSegOnBattery;
@synthesize prefSegOnAc;
@synthesize onBatteryTextField;
@synthesize pluggedInTextField;
@synthesize prefs;

#pragma mark - Initializers

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    if (!(self = [super initWithNibName:@"AdvancedPreferencesView" bundle:nil]))
        return nil;
    
    prefs = [GSPreferences sharedInstance];
    
    return self;
}

#pragma mark - Overrides

- (void)loadView
{
    [super loadView];
    
    NSArray *localizedButtons = [NSArray arrayWithObjects:prefChkPowerSourceBasedSwitching, nil];
    for (NSButton *loc in localizedButtons)
        [loc setTitle:Str([loc title])];
    
    NSArray *localizedLabels = [NSArray arrayWithObjects:onBatteryTextField, pluggedInTextField, nil];
    for (NSTextField *field in localizedLabels)
        [field setStringValue:Str([field stringValue])];
    
    // We don't have a Dynamic Switching mode on legacy machines, so drop that
    // segment from the options entirely.
    if ([GSGPU isLegacyMachine]) {
        [prefSegOnBattery setSegmentCount:2];
        [prefSegOnAc setSegmentCount:2];
    } else {
        [prefSegOnBattery setLabel:Str(@"Dynamic") forSegment:GSPowerSourceBasedSwitchingModeDynamic];
        [prefSegOnAc setLabel:Str(@"Dynamic") forSegment:GSPowerSourceBasedSwitchingModeDynamic];
    }
    
    [prefSegOnBattery setLabel:Str(@"Integrated") forSegment:GSPowerSourceBasedSwitchingModeIntegrated];
    [prefSegOnBattery setLabel:Str(@"Discrete") forSegment:GSPowerSourceBasedSwitchingModeDiscrete];
    
    [prefSegOnAc setLabel:Str(@"Integrated") forSegment:GSPowerSourceBasedSwitchingModeIntegrated];
    [prefSegOnAc setLabel:Str(@"Discrete") forSegment:GSPowerSourceBasedSwitchingModeDiscrete];
    
    // Fit labels after localization.
    [prefSegOnAc sizeToFit];
    [prefSegOnBattery sizeToFit];
}

#pragma mark - GSPreferencesModule protocol

- (NSString *)title
{
    return Str(kAdvancedPreferencesName);
}

- (NSString *)identifier
{
    return kAdvancedPreferencesName;
}

- (NSImage *)image
{
    return [NSImage imageNamed:NSImageNameAdvanced];
}

@end
