//
//  switcher.h
//  gfxCardStatus
//
//  Created by Cody Krieger on 5/7/10.
//  Copyright 2010 Cody Krieger. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum {
	modeForceIntel,
	modeForceNvidia,
	modeDynamicSwitching,
	modeToggleGPU
} switcherMode;

BOOL switcherOpen();  // Initialize driver
void switcherClose(); // Close driver

BOOL switcherSetMode(switcherMode mode); // Sets working mode
BOOL switcherUseIntegrated();			 // Integrated card is in use
BOOL switcherUseDynamicSwitching();		 // Dynamic switching policy enabled