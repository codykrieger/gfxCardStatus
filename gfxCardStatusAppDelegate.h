//
//  gfxCardStatusAppDelegate.h
//  gfxCardStatus
//
//  Created by Cody Krieger on 4/22/10.
//  Copyright 2010 Cody Krieger. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface gfxCardStatusAppDelegate : NSObject <NSApplicationDelegate> {
	NSWindow *window;
	IBOutlet NSMenu *statusMenu;
	NSStatusItem *statusItem;
	NSTimer *timer;
	int timerHit;
}

- (IBAction)updateStatus:(id)sender;
- (IBAction)quit:(id)sender;

@property (assign) IBOutlet NSWindow *window;

@end
