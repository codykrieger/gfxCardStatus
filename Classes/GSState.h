//
//  GSState.h
//  gfxCardStatus
//
//  Created by Cody Krieger on 6/20/11.
//  Copyright 2011 Cody Krieger. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface GSState : NSObject

@property (nonatomic) BOOL usingIntegrated;
@property (nonatomic) BOOL usingLegacy;
@property (nonatomic, retain) NSString *integratedString;
@property (nonatomic, retain) NSString *discreteString;

+ (GSState *)sharedInstance;

@end
