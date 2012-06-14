//
//  GSGPU.h
//  gfxCardStatus
//
//  Created by Cody Krieger on 6/12/12.
//  Copyright (c) 2012 Cody Krieger. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum {
    GSGPUTypeIntegrated,
    GSGPUTypeDiscrete
} GSGPUType;

@protocol GSGPUDelegate <NSObject>
- (void)gpuChangedTo:(GSGPUType)gpu;
@end

@interface GSGPU : NSObject

+ (NSArray *)getGPUNames;
+ (NSString *)integratedGPUName;
+ (NSString *)discreteGPUName;
+ (BOOL)isLegacyMachine;

+ (void)registerForGPUChangeNotifications:(id<GSGPUDelegate>)object;

@end
