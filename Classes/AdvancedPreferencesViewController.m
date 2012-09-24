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

#define kPowerSourceBasedSwitchingExplanationURL [kApplicationWebsiteURL stringByAppendingString:@"/switching.html#power-source-based-switching"]

@implementation AdvancedPreferencesViewController

@synthesize prefs;

#pragma mark - Initializers

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    if (!(self = [super initWithNibName:@"AdvancedPreferencesView" bundle:nil]))
        return nil;
    
    prefs = [GSPreferences sharedInstance];
    
    return self;
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

#pragma mark - AdvancedPreferencesViewController API

- (IBAction)whyButtonClicked:(id)sender
{
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:kPowerSourceBasedSwitchingExplanationURL]];
}

@end
