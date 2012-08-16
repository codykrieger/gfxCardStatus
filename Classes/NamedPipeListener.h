//
//  NamedPipeListener.h
//  NamedPipeListener
//
//  Created by Chris Bentivenga on 8/12/2012.
//  Copyright (c) 2012 Chris Bentivenga. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@protocol NamedPipeListenerDelegate <NSObject>
- (void) messageRecieved:(NSString *)message;
@end

@interface NamedPipeListener : NSObject {
    NSOperationQueue *queue;
    char *_pipeLocation;
}

@property (strong, nonatomic, readonly) NSString *pipeName;
@property (nonatomic,strong) id delegate;
- (id)initWithName:(NSString *)name;
- (NSString *)description;
- (void)listenForChanges;
- (void)listenForChangesInBackground;
- (void)dealloc;

@end
