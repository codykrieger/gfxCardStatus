//
//  GSProcess.h
//  gfxCardStatus
//
//  Created by Cody Krieger on 6/21/11.
//  Copyright 2011 Cody Krieger. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "GSMux.h"

#define kTaskItemName  @"name"
#define kTaskItemPID   @"pid"

@interface GSProcess : NSObject

//+ (NSString *)keyForPowerSource:(PowerSource)powerSource;
//+ (GSSwitcherMode)switcherGetMode;

//+ (BOOL)procInit;
//+ (void)procFree;
+ (NSArray *)getTaskList;

@end
