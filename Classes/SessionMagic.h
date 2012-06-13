//
//  SessionMagic.h
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

@protocol SessionMagicDelegate <NSObject>

- (void)gpuChangedTo:(GPUType)gpu from:(GPUType)from;

@end

@interface SessionMagic : NSObject {
    // preferences-related
    BOOL _canGrowl;
}

@property (nonatomic, unsafe_unretained) id<SessionMagicDelegate> delegate;
@property (nonatomic) BOOL usingIntegrated;
@property (nonatomic) BOOL usingLegacy;
@property (nonatomic, retain) NSString *integratedString;
@property (nonatomic, retain) NSString *discreteString;

+ (SessionMagic *)sharedInstance;

- (void)setCanGrowl:(BOOL)canGrowl;
- (BOOL)canGrowl;

- (void)gpuChangedFrom:(GPUType)from;

@end
