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

+ (NSArray *)getGPUNames;
+ (NSString *)integratedGPUName;
+ (NSString *)discreteGPUName;
+ (BOOL)isLegacyMachine;

+ (void)registerForGPUChangeNotifications:(id<GSGPUDelegate>)object;

@end
