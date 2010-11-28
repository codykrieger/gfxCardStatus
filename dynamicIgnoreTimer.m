//
//  dynamicIgnoreTimer.m
//  gfxCardStatus
//
//  Created by Paulo Cesar Saito on 11/27/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "dynamicIgnoreTimer.h"


@implementation dynamicIgnoreTimer
@synthesize target, selector;

static NSTimer *sharedTimer = nil;
static dynamicIgnoreTimer *sharedInstance = nil;

+ (NSTimer *)sharedTimerWithTarget:(id)target selector:(SEL)selector {	
	if (!sharedTimer) {
		sharedTimer = [[NSTimer alloc] initWithFireDate:[NSDate distantPast] interval:1 target:target selector:selector userInfo:nil repeats:YES];
		[[self sharedInstance] setTarget:target];
		[[self sharedInstance] setSelector:selector];
	}
	return sharedTimer;	
}

+ (dynamicIgnoreTimer *)sharedInstance {
	if (!sharedInstance) {
		sharedInstance = [dynamicIgnoreTimer new];
	}
	return sharedInstance;
}

+ (NSTimer *)sharedTimer {
	return sharedTimer;
}

+ (void)start {
	[[NSRunLoop currentRunLoop] addTimer:sharedTimer forMode:NSDefaultRunLoopMode];
}

+ (void)pause {
	[sharedTimer invalidate];
	sharedTimer = [[NSTimer alloc] initWithFireDate:[NSDate distantPast] interval:1 target:[self sharedInstance].target selector:[self sharedInstance].selector userInfo:nil repeats:YES];
}

@end
