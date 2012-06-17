//
//  GSNotifier.m
//  gfxCardStatus
//
//  Created by Cody Krieger on 6/12/12.
//  Copyright (c) 2012 Cody Krieger. All rights reserved.
//

#import "GSNotifier.h"
#import "NSAttributedString+Hyperlink.h"
#import "GSMux.h"

#define kGPUChangedNotificationKey @"GrowlGPUChanged"

static NSString *_lastMessage = nil;

@interface GSNotifier ()
+ (NSString *)_keyForNotificationType:(GSGPUType)type;
@end

@implementation GSNotifier

#pragma mark - Initializers

+ (GSNotifier *)sharedInstance
{
    static dispatch_once_t pred = 0;
    __strong static GSNotifier *_sharedObject = nil;
    dispatch_once(&pred, ^{
        _sharedObject = [[self alloc] init];
    });
    return _sharedObject;
}

#pragma mark - GSNotifier API

+ (void)showGPUChangeNotification:(GSGPUType)type
{
    // FIXME: Support Mountain Lion's Notification Center here in addition to
    // Growl on supported (>= 10.8.x) machines.
    
    NSString *key = [self _keyForNotificationType:type];
    NSString *title = Str(key);
    
    NSString *cardName = type == GSGPUTypeIntegrated ? [GSGPU integratedGPUName] : [GSGPU discreteGPUName];
    NSString *message = [NSString stringWithFormat:Str([key stringByAppendingString:@"Message"]), cardName];
    
    if (![message isEqualToString:_lastMessage]) {
        [GrowlApplicationBridge notifyWithTitle:title
                                    description:message 
                               notificationName:key
                                       iconData:nil 
                                       priority:0 
                                       isSticky:NO 
                                   clickContext:nil];
        
        _lastMessage = message;
    }
}

+ (void)showOneTimeNotification
{
    NSAlert *versionInfo = [[NSAlert alloc] init];
    [versionInfo setMessageText:Str(@"ThanksForDownloading")];
    [versionInfo setInformativeText:Str(@"PleaseConsiderDonating")];
    NSTextView *accessory = [[NSTextView alloc] initWithFrame:NSMakeRect(0,0,300,15)];
    [accessory insertText:[NSAttributedString hyperlinkFromString:@"http://codykrieger.com/gfxCardStatus" 
                                                          withURL:[NSURL URLWithString:@"http://codykrieger.com/gfxCardStatus"]]];
    [accessory setEditable:NO];
    [accessory setDrawsBackground:NO];
    [versionInfo setAccessoryView:accessory];
    [versionInfo addButtonWithTitle:Str(@"DontShowAgain")];
    [versionInfo runModal];
}

+ (void)showUnsupportedMachineMessage
{
    NSAlert *alert = [NSAlert alertWithMessageText:Str(@"UnsupportedMachine")
                                     defaultButton:Str(@"OhISee")
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

+ (NSString *)_keyForNotificationType:(GSGPUType)type
{
    if (type == GSGPUTypeIntegrated || type == GSGPUTypeDiscrete)
        return kGPUChangedNotificationKey;
    
    assert(false); // We shouldn't ever get here.
    
    return nil;
}

@end
