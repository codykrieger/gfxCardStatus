//
//  GSMux.h
//  gfxCardStatus
//
//  Created by Cody Krieger on 6/21/11.
//  Copyright 2011 Cody Krieger. All rights reserved.
//

typedef enum {
    GSSwitcherModeForceIntegrated,
    GSSwitcherModeForceDiscrete,
    GSSwitcherModeDynamicSwitching,
    GSSwitcherModeToggleGPU
} GSSwitcherMode;

#define kDriverClassName "AppleGraphicsControl"

@interface GSMux : NSObject

// Switching driver initialization and cleanup routines.
+ (BOOL)switcherOpen;
+ (void)switcherClose;

+ (BOOL)setMode:(GSSwitcherMode)mode;
+ (BOOL)isUsingIntegratedGPU;
+ (BOOL)isUsingIntegratedGPU;
+ (BOOL)isUsingDynamicSwitching;
+ (BOOL)isUsingOldStyleSwitchPolicy;

@end
