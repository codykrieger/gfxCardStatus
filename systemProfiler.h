//
//  systemProfiler.h
//  gfxCardStatus
//
//  Created by Cody Krieger on 4/22/10.
//  Copyright 2010 Cody Krieger. All rights reserved.
//

#import <Foundation/Foundation.h>

// Whether the integrated graphic is currently in use
// legacy is set to 'usingLate08Or09Model'
BOOL isUsingIntegratedGraphics(BOOL *legacy);
