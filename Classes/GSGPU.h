//
//  GSGPU.h
//  gfxCardStatus
//
//  Created by Cody Krieger on 6/12/12.
//  Copyright (c) 2012 Cody Krieger. All rights reserved.
//

typedef enum {
    GSGPUTypeIntegrated,
    GSGPUTypeDiscrete
} GSGPUType;

@protocol GSGPUDelegate <NSObject>
- (void)GPUDidChangeTo:(GSGPUType)gpu;
@end

@interface GSGPU : NSObject

// If any of the following three method names are confusing...PEBKAC.
+ (NSArray *)getGPUNames;
+ (NSString *)integratedGPUName;
+ (NSString *)discreteGPUName;
// Whether or not the machine is an old 9400M/9600M GT machine. We have to treat
// those a little differently all other machines are effectively the same.
+ (BOOL)isLegacyMachine;

// What it says.
+ (void)registerForGPUChangeNotifications:(id<GSGPUDelegate>)object;

// Fires off the display change notification manually in order to trigger menu
// changes, notifications, etc. when we otherwise wouldn't receive a display
// change notification that we want.
+ (void)fireManualChangeNotification;

@end
