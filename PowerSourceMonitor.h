//
//  PowerSourceMonitor.h
//  gfxCardStatus
//
//  Created by Ikeuchi on 10/05/16.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

typedef enum {
	psACAdaptor,
	psBattery,
	psUnknown
} PowerSource;

@protocol PowerSourceMonitorDelegate<NSObject>
- (void)powerSourceChanged:(PowerSource)powerSource;
@end


@interface PowerSourceMonitor : NSObject {
	id<PowerSourceMonitorDelegate> delegate;
}

@property (nonatomic, assign) id<PowerSourceMonitorDelegate> delegate;
@property (nonatomic, readonly, getter=currentPowerSource) PowerSource currentPowerSource;

- (PowerSourceMonitor *)initWithDelegate:(id<PowerSourceMonitorDelegate>)delegate;
+ (PowerSourceMonitor *)monitorWithDelegate:(id<PowerSourceMonitorDelegate>)delegate;

- (PowerSource)currentPowerSource;

- (void)powerSourceChanged:(PowerSource)powerSource;

@end
