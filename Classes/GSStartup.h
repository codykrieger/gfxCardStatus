//
//  GSStartup.h
//  gfxCardStatus
//
//  Created by Cody Krieger on 6/12/12.
//  Copyright (c) 2012 Cody Krieger. All rights reserved.
//

@interface GSStartup : NSObject

// Whether or not the app exists in the current user's Login Items list.
+ (BOOL)existsInStartupItems;
// Put the app in the current user's Login Items list.
+ (void)loadAtStartup:(BOOL)value;

@end
