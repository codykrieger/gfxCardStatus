//
//  NSAttributedString+Hyperlink.m
//  gfxCardStatus
//
//  Created by Cody Krieger on 12/9/10.
//  Copyright 2010 Cody Krieger. All rights reserved.
//

#import "NSAttributedString+Hyperlink.h"


@implementation NSAttributedString (Hyperlink)

+(id)hyperlinkFromString:(NSString*)inString withURL:(NSURL*)aURL {
    NSMutableAttributedString *attrString = [[NSMutableAttributedString alloc] initWithString: inString];
    NSRange range = NSMakeRange(0, [attrString length]);
    
    [attrString beginEditing];
    
    // string attrs
    [attrString addAttribute:NSLinkAttributeName value:[aURL absoluteString] range:range];
    [attrString addAttribute:NSForegroundColorAttributeName value:[NSColor blueColor] range:range];
    [attrString addAttribute:
     NSUnderlineStyleAttributeName value:[NSNumber numberWithInt:NSSingleUnderlineStyle] range:range];
    
    [attrString endEditing];
    
    return [attrString autorelease];
}

@end
