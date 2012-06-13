//
//  PreferencesWindowController.m
//  gfxCardStatus
//
//  Created by Michal Vančo on 7/11/11.
//  Copyright 2011 Michal Vančo. All rights reserved.
//

#import "PreferencesWindowController.h"

@interface PreferencesWindowController ()
@property(nonatomic, retain) NSArray *modules;
- (void)createToolbar;
@end

@implementation PreferencesWindowController

@synthesize modules;

- (id)init {
    self = [super init];
    if (self) {
        NSWindow *prefsWindow = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 300, 200) 
                                                             styleMask:(NSTitledWindowMask | NSClosableWindowMask) 
                                                               backing:NSBackingStoreBuffered defer:YES];
        [prefsWindow setShowsToolbarButton:NO];
        self.window = prefsWindow;
        
        [self createToolbar];
    }
    return self;
}

- (void)createToolbar {
    NSToolbar *toolbar = [[NSToolbar alloc] initWithIdentifier:@"PreferencesToolbar"];
    
    [toolbar setDisplayMode:NSToolbarDisplayModeIconAndLabel];
    [toolbar setAllowsUserCustomization:NO];
    [toolbar setDelegate:self];
    [toolbar setAutosavesConfiguration:NO];
    
    [self.window setToolbar:toolbar];
}

- (void)showWindow:(id)sender {
    [self.window center];
    [super showWindow:sender];
}

- (id<PreferencesModule>)moduleForIdentifier:(NSString *)identifier {
    for (id<PreferencesModule> module in self.modules) {
        if ([[module identifier] isEqualToString:identifier]) {
            return module;
        }
    }
    
    return nil;
}

- (void)changeToModule:(id<PreferencesModule>)module {
    [[currentModule view] removeFromSuperview];
    
    // The view which will be displayed
    NSView *newView = [module view];
    
    // Resize the window
    // Be sure to keep the top-left corner stationary
    NSRect newWindowFrame = [self.window frameRectForContentRect:[newView frame]];
    newWindowFrame.origin = [self.window frame].origin;
    newWindowFrame.origin.y -= newWindowFrame.size.height - [self.window frame].size.height;
    [self.window setFrame:newWindowFrame display:YES animate:YES];
    
    [[self.window toolbar] setSelectedItemIdentifier:[module identifier]];
    [self.window setTitle:[module title]];
    
    // Call the optional protocol method if the module implements it
    if ([(NSObject *)module respondsToSelector:@selector(willBeDisplayed)]) {
        [module willBeDisplayed];
    }
    
    // Show the view
    currentModule = module;
    [[self.window contentView] addSubview:[currentModule view]];
    
    // Autosave the selection
    [[NSUserDefaults standardUserDefaults] setObject:[module identifier] forKey:@"PreferencesWindowSelection"];
}

- (void)selectModule:(NSToolbarItem *)sender {
    if (![sender isKindOfClass:[NSToolbarItem class]]) return;
    
    id<PreferencesModule> module = [self moduleForIdentifier:[sender itemIdentifier]];
    if (!module) return;
    
    [self changeToModule:module];
}

- (void)setModules:(NSArray *)newModules {
    if (newModules == modules) return;
    
    if (modules) {
        modules = nil;
    }
    
    if (!newModules) return;
    
    modules = newModules;
    
    // Reset the toolbar items
    NSToolbar *toolbar = [self.window toolbar];
    if (toolbar) {
        NSInteger index = [[toolbar items] count]-1;
        while (index > 0) {
            [toolbar removeItemAtIndex:index];
            index--;
        }
        
        // Add the new items
        for (id<PreferencesModule> module in self.modules) {
            [toolbar insertItemWithItemIdentifier:[module identifier] atIndex:[[toolbar items] count]];
        }
    }
    
    // Change to the correct module
    // This is where we restore the autosaved info
    if ([self.modules count]) {
        id<PreferencesModule> defaultModule = nil;
        
        // Check the autosave info
        NSString *savedIdentifier = [[NSUserDefaults standardUserDefaults] stringForKey:@"PreferencesWindowSelection"];
        defaultModule = [self moduleForIdentifier:savedIdentifier];
        
        if (!defaultModule) {
            defaultModule = [self.modules objectAtIndex:0];
        }
        
        [self changeToModule:defaultModule];
    }
}


#pragma mark - 
#pragma mark NSToolbar delegate

- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar {
    NSMutableArray *identifiers = [NSMutableArray array];
    
    for (id<PreferencesModule> module in self.modules) {
        [identifiers addObject:[module identifier]];
    }
    
    return identifiers;
}

- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar {
    return nil;
}

- (NSArray *)toolbarSelectableItemIdentifiers:(NSToolbar *)toolbar {
    return [self toolbarAllowedItemIdentifiers:toolbar];
}

- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag {
    id<PreferencesModule> module = [self moduleForIdentifier:itemIdentifier];
    
    NSToolbarItem *item = [[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier];
    if (!module) return item;
    
    // Set the attributes of the item
    [item setLabel:[module title]];
    [item setImage:[module image]];
    [item setTarget:self];
    [item setAction:@selector(selectModule:)];
    
    return item;
}

@end
