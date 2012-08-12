//
//  NamedPipeListener.m
//  NamedPipeListener
//
//  Created by Chris Bentivenga on 8/12/2012.
//  Copyright (c) 2012 Chris Bentivenga. All rights reserved.
//

#import "NamedPipeListener.h"
#import <sys/stat.h>

#define MAX_BUF_SIZE 255

@implementation NamedPipeListener
@synthesize delegate;

// Creates the named pipe listener with the specified name
-(NamedPipeListener *) initWithName:(NSString*)name{
    if (self = [super init]) {
        _pipeName = name;
        const char* tmp = [[@"/tmp/" stringByAppendingString:_pipeName] UTF8String];
        _pipeLocation = malloc(sizeof(char) * strlen(tmp));
        strcpy(_pipeLocation, tmp);
        
        remove(_pipeLocation);
        int ret_val = mkfifo(_pipeLocation, 0644);
        if ((ret_val == -1) && (errno != EEXIST)) {
            perror("Error creating the named pipe");
        }
        
    }
    return self;
}

-(NSString *) description{
    return [NSString stringWithFormat:@"Pipe Name: %@", _pipeName];
}

// Listen
-(void)listenForChanges{
    char buf[MAX_BUF_SIZE];
    char * tmp = malloc(sizeof(char) *strlen(_pipeLocation));
    strcpy(tmp, _pipeLocation);
    
    int fd = open(tmp, O_RDONLY);
    
    free(tmp);
    
    long size = read(fd, buf, MAX_BUF_SIZE);
    buf[size-1] = '\0';
    
    @autoreleasepool {
        NSString *message = [NSString stringWithUTF8String:buf];
        [delegate messageRecieved:message];
    }
    
    close(fd);
}

-(void)listenForChangesInBackground{
    if(queue == nil){
        queue = [[NSOperationQueue alloc] init];
    }
    
    [queue addOperationWithBlock: ^{
        [self listenForChanges];
        [self listenForChangesInBackground];
    }];
}

-(void)dealloc{
    remove(_pipeLocation);
    free(_pipeLocation);
}

-(void) messageRecieved: (NSString*) message{
    NSLog(@"%@", message);
}

@end
