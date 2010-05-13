//
//  switcher.h
//  gfxCardStatus
//
//  Created by Cody Krieger on 5/7/10.
//  Copyright 2010 Cody Krieger. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface switcher : NSObject {

}

+ (void)forceIntel;
+ (void)forceNvidia;
+ (void)dynamicSwitching;
+ (void)toggleGPU;

@end
