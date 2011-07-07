//
//  SystemInfo.h
//  gfxCardStatus
//
//  Created by Cody Krieger on 6/21/11.
//  Copyright 2011 Cody Krieger. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "MuxMagic.h"

#define kTaskItemName  @"name"
#define kTaskItemPID   @"pid"

@interface SystemInfo : NSObject

+ (NSString *)keyForPowerSource:(PowerSource)powerSource;
+ (SwitcherMode)switcherGetMode;

+ (BOOL)procInit;
+ (void)procFree;
+ (NSArray *)getTaskList;

+ (NSDictionary *)getGraphicsProfile;

@end
