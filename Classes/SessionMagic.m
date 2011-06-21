//
//  SessionMagic.m
//  gfxCardStatus
//
//  Created by Cody Krieger on 6/20/11.
//  Copyright 2011 Cody Krieger. All rights reserved.
//

#import "SessionMagic.h"
#import "PrefsController.h"

static SessionMagic *sharedInstance = nil;

@implementation SessionMagic

@synthesize usingIntegrated, integratedString, discreteString;

- (id)init {
    self = [super init];
    if (self) {
        _canGrowl = YES;
    }
    
    return self;
}

- (void)setCanGrowl:(BOOL)canGrowl {
    _canGrowl = canGrowl;
}

- (BOOL)canGrowl {
    return (_canGrowl && [[PrefsController sharedInstance] shouldGrowl]);
}

#pragma mark -
#pragma Singleton methods

+ (SessionMagic *)sharedInstance {
    @synchronized(self) {
        if (sharedInstance == nil)
            sharedInstance = [[super allocWithZone:NULL] init];
    }
    return sharedInstance;
}

+ (id)allocWithZone:(NSZone *)zone {
    @synchronized(self) {
        if (sharedInstance == nil) {
            sharedInstance = [super allocWithZone:zone];
            return sharedInstance; // assignment and return on first allocation
        }
    }
    return nil; // on subsequent allocation attempts return nil
}

- (id)copyWithZone:(NSZone *)zone {
    return self;
}

- (id)retain {
    return self;
}

- (NSUInteger)retainCount {
    return NSUIntegerMax;  //denotes an object that cannot be released
}

- (oneway void)release {
    //do nothing
}

- (id)autorelease {
    return self;
}

@end
