//
//  NSAttributedString+Hyperlink.h
//  gfxCardStatus
//
//  Created by Cody Krieger on 12/9/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface NSAttributedString (Hyperlink)
+ (id)hyperlinkFromString:(NSString*)inString withURL:(NSURL*)aURL;
@end
