//
//  GSStartup.h
//  gfxCardStatus
//
//  Created by Cody Krieger on 6/12/12.
//  Copyright (c) 2012 Cody Krieger. All rights reserved.
//

@interface GSStartup : NSObject

+ (BOOL)existsInStartupItems;
+ (void)loadAtStartup:(BOOL)value;

@end
