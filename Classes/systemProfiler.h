//
//  systemProfiler.h
//  gfxCardStatus
//
//  Created by Cody Krieger on 4/22/10.
//  Copyright 2010 Cody Krieger. All rights reserved.
//

#import <Foundation/Foundation.h>

// get back a dictionary with some information indicative of what GPUs the machine
// contains, and whether it's using an integrated chipset or not
NSDictionary* getGraphicsProfile();
