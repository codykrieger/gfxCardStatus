//
//  GSNotifier.h
//  gfxCardStatus
//
//  Created by Cody Krieger on 6/12/12.
//  Copyright (c) 2012 Cody Krieger. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Growl/Growl.h>

typedef enum {
    GSNotificationTypeGPUDidChangeToIntegrated,
    GSNotificationTypeGPUDidChangeToDiscrete
} GSNotificationType;

@interface GSNotifier : NSObject<GrowlApplicationBridgeDelegate>

+ (GSNotifier *)sharedInstance;

+ (void)queueNotification:(GSNotificationType)type;
+ (void)showOneTimeNotification;
+ (void)showUnsupportedMachineMessage;

@end
