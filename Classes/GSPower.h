//
//  GSPower.h
//  gfxCardStatus
//
//  Created by Cody Krieger on 6/12/12.
//  Copyright (c) 2012 Cody Krieger. All rights reserved.
//

#import <Cocoa/Cocoa.h>

typedef enum {
    GSPowerTypeAC,
    GSPowerTypeBattery,
    GSPowerTypeUnknown
} GSPowerType;

@protocol GSPowerDelegate <NSObject>
- (void)powerSourceChanged:(GSPowerType)type;
@end

@interface GSPower : NSObject

@property (unsafe_unretained) id<GSPowerDelegate> delegate;
@property (readonly, getter=currentPowerSource) GSPowerType currentPowerSource;

- (GSPower *)initWithDelegate:(id<GSPowerDelegate>)object;
- (void)powerSourceChanged:(GSPowerType)powerSource;

@end
