//
//  GSProcess.h
//  gfxCardStatus
//
//  Created by Cody Krieger on 6/21/11.
//  Copyright 2011 Cody Krieger. All rights reserved.
//

#import "GSMux.h"

#define kTaskItemName  @"name"
#define kTaskItemPID   @"pid"

@interface GSProcess : NSObject

+ (NSArray *)getTaskList;

@end
