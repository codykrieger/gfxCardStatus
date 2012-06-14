//
//  GSNotifier.m
//  gfxCardStatus
//
//  Created by Cody Krieger on 6/12/12.
//  Copyright (c) 2012 Cody Krieger. All rights reserved.
//

#import "GSNotifier.h"
#import "NSAttributedString+Hyperlink.h"
#import "GSGPU.h"
#import "GSMux.h"

#define kGPUChangedNotificationKey @"GrowlGPUChanged"

@interface GSNotifier ()
+ (NSString *)_keyForNotificationType:(GSNotificationType)type;
@end

@implementation GSNotifier

#pragma mark - Initializers

+ (GSNotifier *)sharedInstance
{
    static dispatch_once_t pred = 0;
    __strong static GSNotifier *_sharedObject = nil;
    dispatch_once(&pred, ^{
        _sharedObject = [[self alloc] init]; // or some other init method
    });
    return _sharedObject;
}

#pragma mark - GSNotifier API

+ (void)queueNotification:(GSNotificationType)type
{
    // FIXME: Support Mountain Lion's Notification Center here in addition to
    // Growl on supported (>= 10.8.x) machines.
    
    NSString *key = [self _keyForNotificationType:type];
    NSString *title = Str(key);
    
    NSString *cardName = type == GSNotificationTypeGPUChangedToIntegrated ? [GSGPU integratedGPUName] : [GSGPU discreteGPUName];
    NSString *message = [NSString stringWithFormat:Str([title stringByAppendingString:@"Message"]), cardName];
    
    [GrowlApplicationBridge notifyWithTitle:title
                                description:message 
                           notificationName:key
                                   iconData:nil 
                                   priority:0 
                                   isSticky:NO 
                               clickContext:nil];
}

+ (void)showOneTimeNotification
{
    // FIXME: Localize all of these huge strings
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
                                     defaultButton:@"Oh, I see." 
                                   alternateButton:nil 
                                       otherButton:nil 
                         informativeTextWithFormat:@""];
    [alert runModal];
}

#pragma mark - GrowlApplicationBridgeDelegate protocol

- (NSDictionary *)registrationDictionaryForGrowl
{
    return [NSDictionary dictionaryWithContentsOfFile:
            [[NSBundle mainBundle] pathForResource:@"Growl Registration Ticket" 
                                            ofType:@"growlRegDict"]];
}

#pragma mark - Private helpers

+ (NSString *)_keyForNotificationType:(GSNotificationType)type
{
    if (type == GSNotificationTypeGPUChangedToIntegrated
        || type == GSNotificationTypeGPUChangedToDiscrete) {
        return kGPUChangedNotificationKey;
    }
    
    assert(false); // We shouldn't ever get here.
    
    return nil;
}

@end
