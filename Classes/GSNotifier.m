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
#import "GSPreferences.h"

#define kGPUChangedNotificationKey @"GrowlGPUChanged"

#define kIntegratedOnlyMessageExplanationURL [kApplicationWebsiteURL stringByAppendingString:@"/switching.html#integrated-only-mode-limitations"]

@interface GSNotifier () <NSUserNotificationCenterDelegate>
- (NSString *)_keyForNotificationType:(GSGPUType)type;
@end

@implementation GSNotifier {
    NSString *_lastMessage;
}

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

- (id)init
{
    if (!(self = [super init]))
        return nil;

    [NSUserNotificationCenter defaultUserNotificationCenter].delegate = self;

    return self;
}

#pragma mark - GSNotifier API

- (void)showGPUChangeNotification:(GSGPUType)type
{
    // Get the localized notification name and message, as well as the current
    // GPU name for display in the message.
    NSString *key = [self _keyForNotificationType:type];
    NSString *title = Str(key);
    NSString *cardName = type == GSGPUTypeIntegrated ? [GSGPU integratedGPUName] : [GSGPU discreteGPUName];
    NSString *message = [NSString stringWithFormat:Str([key stringByAppendingString:@"Message"]), cardName];

    // Make sure that we don't display the notification if it's the same message
    // as the last one we fired off. Because that's unbelievably annoying. Also
    // check to make sure the user even wants to see the notifications in the
    // first place.
    if (![message isEqualToString:_lastMessage] && [GSPreferences sharedInstance].shouldDisplayNotifications) {
        NSUserNotification *notification = [[NSUserNotification alloc] init];
        notification.hasActionButton = NO;
        notification.title = title;
        notification.informativeText = message;
        notification.identifier = [NSUUID UUID].UUIDString;
        [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];

        _lastMessage = message;
    }
}

- (void)showOneTimeNotification
{
    NSAlert *versionInfo = [[NSAlert alloc] init];
    [versionInfo setMessageText:Str(@"ThanksForDownloading")];
    [versionInfo setInformativeText:Str(@"PleaseConsiderDonating")];
    NSTextView *accessory = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, 300, 15)];
    [accessory insertText:[NSAttributedString hyperlinkFromString:kApplicationWebsiteURL
                                                          withURL:[NSURL URLWithString:kApplicationWebsiteURL]]];
    [accessory setEditable:NO];
    [accessory setDrawsBackground:NO];
    [versionInfo setAccessoryView:accessory];
    [versionInfo addButtonWithTitle:Str(@"DontShowAgain")];
    [versionInfo runModal];
}

- (void)showUnsupportedMachineMessage
{
    NSAlert *alert = [NSAlert alertWithMessageText:Str(@"UnsupportedMachine")
                                     defaultButton:Str(@"OhISee")
                                   alternateButton:nil 
                                       otherButton:nil 
                         informativeTextWithFormat:@""];
    [alert runModal];
}

- (void)showCantSwitchToIntegratedOnlyMessage:(NSArray *)taskList
{
    NSString *messageKey = [NSString stringWithFormat:@"Can'tSwitchToIntegratedOnly%@", (taskList.count > 1 ? @"Plural" : @"Singular")];

    NSMutableString *descriptionText = [[NSMutableString alloc] init];
    for (NSString *taskName in taskList)
        [descriptionText appendFormat:@"%@\n", taskName];

    NSAlert *alert = [NSAlert alertWithMessageText:Str(messageKey)
                                     defaultButton:@"OK"
                                   alternateButton:@"Why?"
                                       otherButton:nil
                         informativeTextWithFormat:@"%@", descriptionText];

    if ([alert runModal] == NSAlertAlternateReturn)
        [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:kIntegratedOnlyMessageExplanationURL]];
}

#pragma mark - NSUserNotificationCenterDelegate protocol

- (void)userNotificationCenter:(NSUserNotificationCenter *)center didDeliverNotification:(NSUserNotification *)notification
{
    [center removeDeliveredNotification:notification];
}

- (BOOL)userNotificationCenter:(NSUserNotificationCenter *)center shouldPresentNotification:(NSUserNotification *)notification
{
    return YES;
}

#pragma mark - Private helpers

- (NSString *)_keyForNotificationType:(GSGPUType)type
{
    if (type == GSGPUTypeIntegrated || type == GSGPUTypeDiscrete)
        return kGPUChangedNotificationKey;
    
    assert(false); // We shouldn't ever get here.
    
    return nil;
}

@end
