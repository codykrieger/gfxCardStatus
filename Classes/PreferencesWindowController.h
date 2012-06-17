//
//  PreferencesWindowController.h
//  gfxCardStatus
//
//  Created by Michal Vančo on 7/11/11.
//  Copyright 2011 Michal Vančo. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "GSPreferencesModule.h"

@interface PreferencesWindowController : NSWindowController <NSToolbarDelegate> {
@private
    NSArray *_modules;
    id<GSPreferencesModule> currentModule;
}

- (void)setModules:(NSArray *)newModules;

@end
