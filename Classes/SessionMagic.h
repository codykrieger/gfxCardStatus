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

- (void)gpuChangedTo:(GPUType)gpu;

@end

@interface SessionMagic : NSObject {
    id <SessionMagicDelegate> delegate;
    
    // preferences-related
    BOOL _canGrowl;
    
    // current machine state
    BOOL _usingIntegrated;
    BOOL _usingLegacy;
    
    NSString *_integratedString;
    NSString *_discreteString;
}

@property (nonatomic, assign) id <SessionMagicDelegate> delegate;
@property (nonatomic) BOOL usingIntegrated;
@property (nonatomic) BOOL usingLegacy;
@property (nonatomic, retain) NSString *integratedString;
@property (nonatomic, retain) NSString *discreteString;

+ (SessionMagic *)sharedInstance;

- (void)setCanGrowl:(BOOL)canGrowl;
- (BOOL)canGrowl;

- (void)gpuChanged;

@end
