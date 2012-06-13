//
//  GSPower.h
//  gfxCardStatus
//
//  Created by Cody Krieger on 6/12/12.
//  Copyright (c) 2012 Cody Krieger. All rights reserved.
//

#import <Foundation/Foundation.h>

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

@end
