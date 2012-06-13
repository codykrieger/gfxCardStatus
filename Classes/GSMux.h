//
//  GSMux.h
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
} SwitcherMode;

#define kDriverClassName "AppleGraphicsControl"

@interface GSMux : NSObject

+ (BOOL)switcherOpen;                       // Initialize driver
+ (void)switcherClose;                      // Close driver

+ (BOOL)switcherSetMode:(SwitcherMode)mode; // Sets working mode
+ (BOOL)isUsingIntegrated;                  // Is integrated card in use?
+ (BOOL)isUsingDynamicSwitching;            // Is dynamic switching enabled?

@end
