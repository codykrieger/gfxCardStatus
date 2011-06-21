//
//  MuxMagic.h
//  gfxCardStatus
//
//  Created by Cody Krieger on 6/21/11.
//  Copyright 2011 Cody Krieger. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum {
    modeForceIntegrated,
    modeForceDiscrete,
    modeDynamicSwitching,
    modeToggleGPU
} switcherMode;

#define kDriverClassName "AppleGraphicsControl"

@interface MuxMagic : NSObject

+ (BOOL)switcherOpen;                       // Initialize driver
+ (void)switcherClose;                      // Close driver

+ (BOOL)switcherSetMode:(switcherMode)mode; // Sets working mode
+ (BOOL)switcherUseIntegrated;              // Integrated card is in use
+ (BOOL)switcherUseDynamicSwitching;        // Dynamic switching policy enabled

@end
