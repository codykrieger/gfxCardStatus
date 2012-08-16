//
//  GSNamedPipe.h
//  gfxCardStatus
//
//  Created by Chris Bentivenga on 8/12/2012.
//  Copyright (c) 2012 Cody Krieger. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "GSMenuController.h"

@class NamedPipeListener;

@interface GSNamedPipe : NSObject {
    NamedPipeListener *listener;
    GSMenuController *menuController;
}

- (id)initWithController:(GSMenuController *)controller;

@end
