//
//  dynamicIgnoreTimer.h
//  gfxCardStatus
//
//  Created by Paulo Cesar Saito on 11/27/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface dynamicIgnoreTimer : NSObject {
	id target;
	SEL selector;
}

@property (nonatomic, retain) id target;
@property (nonatomic, assign) SEL selector;

+ (NSTimer *)sharedTimerWithTarget:(id)target selector:(SEL)selector;
+ (NSTimer *)sharedTimer;
+ (dynamicIgnoreTimer *)sharedInstance;
+ (void)start;
+ (void)pause;
	
@end
