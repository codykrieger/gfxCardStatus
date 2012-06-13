//
//  GSNotifier.m
//  gfxCardStatus
//
//  Created by Cody Krieger on 6/12/12.
//  Copyright (c) 2012 Cody Krieger. All rights reserved.
//

#import "GSNotifier.h"
#import "NSAttributedString+Hyperlink.h"

@implementation GSNotifier

// FIXME: localize all of these huge strings

+ (void)showOneTimeNotification
{
    NSAlert *versionInfo = [[NSAlert alloc] init];
    [versionInfo setMessageText:@"Thanks for downloading gfxCardStatus!"];
    [versionInfo setInformativeText:@"If you find it useful, please consider donating to support development and hosting costs. You can find the donate link, and the FAQ page (which you should REALLY read) at the gfxCardStatus website:"];
    NSTextView *accessory = [[NSTextView alloc] initWithFrame:NSMakeRect(0,0,300,15)];
    [accessory insertText:[NSAttributedString hyperlinkFromString:@"http://codykrieger.com/gfxCardStatus" 
                                                          withURL:[NSURL URLWithString:@"http://codykrieger.com/gfxCardStatus"]]];
    [accessory setEditable:NO];
    [accessory setDrawsBackground:NO];
    [versionInfo setAccessoryView:accessory];
    [versionInfo addButtonWithTitle:@"Don't show this again!"];
    [versionInfo runModal];
}

+ (void)showUnsupportedMachineMessage
{
    NSAlert *alert = [NSAlert alertWithMessageText:@"You are using a system that gfxCardStatus does not support. Please ensure that you are using a MacBook Pro with dual GPUs." 
                                     defaultButton:@"Oh, I see." alternateButton:nil otherButton:nil informativeTextWithFormat:@""];
    [alert runModal];
}

@end
