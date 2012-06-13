//
//  GSState.h
//  gfxCardStatus
//
//  Created by Cody Krieger on 6/20/11.
//  Copyright 2011 Cody Krieger. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum {
    kGPUTypeIntegrated,
    kGPUTypeDiscrete
} GPUType;

@protocol GSStateDelegate <NSObject>

- (void)gpuChangedTo:(GPUType)gpu from:(GPUType)from;

@end

@interface GSState : NSObject

@property (nonatomic, unsafe_unretained) id<GSStateDelegate> delegate;
@property (nonatomic) BOOL usingIntegrated;
@property (nonatomic) BOOL usingLegacy;
@property (nonatomic, retain) NSString *integratedString;
@property (nonatomic, retain) NSString *discreteString;

+ (GSState *)sharedInstance;

- (void)gpuChangedFrom:(GPUType)from;

@end
