//
//  GSPower.h
//  gfxCardStatus
//
//  Created by Cody Krieger on 6/12/12.
//  Copyright (c) 2012 Cody Krieger. All rights reserved.
//

#import "GSPreferences.h"

typedef enum {
    GSPowerTypeAC,
    GSPowerTypeBattery,
    GSPowerTypeUnknown
} GSPowerType;

@interface GSPower : NSObject {
    GSPreferences *_prefs;
}

+ (GSPower *)sharedInstance;
- (GSPowerType)currentPowerSource;
- (void)powerSourceChanged:(GSPowerType)type;

@end
