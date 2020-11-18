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

@protocol GSMuxProtocol <NSObject>
@required
// Switching driver initialization and cleanup routines.
- (BOOL)switcherOpen;
- (void)switcherClose;

- (BOOL)setMode:(GSSwitcherMode)mode;

- (BOOL)isUsingIntegratedGPU;
- (BOOL)isUsingDiscreteGPU;
- (BOOL)isUsingDynamicSwitching;
// Whether or not a machine is using the old-style "you must log out first"
// switching policy or not. We kick machines into said policy when we switch to
// Integrated Only or Discrete Only for reliability and consistency purposes.
- (BOOL)isUsingOldStyleSwitchPolicy;

- (BOOL)isOnIntegratedOnlyMode;
- (BOOL)isOnDiscreteOnlyMode;
@end

@interface GSMux : NSObject
+ (id<GSMuxProtocol>)defaultMux;
@end
