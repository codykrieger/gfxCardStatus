//
//  GSNamedPipe.m
//  gfxCardStatus
//
//  Created by Chris Bentivenga on 8/12/2012.
//  Copyright (c) 2012 Cody Krieger. All rights reserved.
//

#import "NamedPipeListener.h"
#import "GSNamedPipe.h"
#import "GSMux.h"

#define INTEGRATED @"integrated"
#define DISCRETE @"discrete"
#define DYNAMIC @"dynamic"

@implementation GSNamedPipe

-(GSNamedPipe *) init{
    if(self = [super init]){
        listener = [[NamedPipeListener alloc] initWithName:@"gfxCardStatus"];
        [listener setDelegate:self];
        [listener listenForChangesInBackground];
    }
    return self;
}

-(void) messageRecieved: (NSString*) message{
    GTMLoggerDebug(@"Message recieved from pipe: %@", message);
    
    
    BOOL retval = NO;
    if ([message isEqualToString:INTEGRATED]) {
        GTMLoggerInfo(@"Setting Integrated only...");
        retval = [GSMux setMode:GSSwitcherModeForceIntegrated];
    }
    if ([message isEqualToString:DISCRETE]) {
        GTMLoggerInfo(@"Setting Discrete only...");
        retval = [GSMux setMode:GSSwitcherModeForceDiscrete];
    }
    if ([message isEqualToString:DYNAMIC]) {
        GTMLoggerInfo(@"Setting dynamic switching...");
        retval = [GSMux setMode:GSSwitcherModeDynamicSwitching];
    }
}

@end
