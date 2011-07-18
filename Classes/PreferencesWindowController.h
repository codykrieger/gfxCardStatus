//
//  PreferencesWindowController.h
//  gfxCardStatus
//
//  Created by Michal Vančo on 7/11/11.
//  Copyright 2011 Michal Vančo. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "PreferencesModule.h"

@interface PreferencesWindowController : NSWindowController <NSToolbarDelegate> {
@private
    NSArray *modules;
    id<PreferencesModule> currentModule;
}

- (void)setModules:(NSArray *)newModules;

@end
