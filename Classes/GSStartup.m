//
//  GSStartup.m
//  gfxCardStatus
//
//  Created by Cody Krieger on 6/12/12.
//  Copyright (c) 2012 Cody Krieger. All rights reserved.
//

#import "GSStartup.h"

#define kApplicationName @"gfxCardStatus.app"

@implementation GSStartup

#pragma mark - GSStartup API

+ (void)copyLoginItems:(LSSharedFileListRef *)loginItems andCurrentLoginItem:(LSSharedFileListItemRef *)currentItem {
    *loginItems = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
    
    if (*loginItems) {
        UInt32 seedValue;
        NSArray *loginItemsArray = (__bridge NSArray *)LSSharedFileListCopySnapshot(*loginItems, &seedValue);
        
        for (id item in loginItemsArray) {
            LSSharedFileListItemRef itemRef = (__bridge LSSharedFileListItemRef)item;
            CFURLRef URL = NULL;
            
            if (LSSharedFileListItemResolve(itemRef, 0, &URL, NULL) == noErr) {
                if ([[(__bridge NSURL *)URL path] hasSuffix:kApplicationName]) {
                    GSLogDebug(@"Exists in startup items.");
                    
                    *currentItem = (__bridge_retained LSSharedFileListItemRef)item;
                    CFRelease(URL);
                    
                    break;
                }
                
                CFRelease(URL);
            }
        }
        
        CFRelease((__bridge CFArrayRef)loginItemsArray);
    }
}

+ (BOOL)existsInStartupItems {
    BOOL exists;
    LSSharedFileListRef loginItems = NULL;
    LSSharedFileListItemRef currentItem = NULL;
    
    [self copyLoginItems:&loginItems andCurrentLoginItem:&currentItem];
    
    exists = (currentItem != NULL);
    
    if (loginItems != NULL)
        CFRelease(loginItems);
    if (currentItem != NULL)
        CFRelease(currentItem);
    
    return exists;
}

+ (void)loadAtStartup:(BOOL)value {
    NSURL *thePath = [[NSBundle mainBundle] bundleURL];
    LSSharedFileListRef loginItems = NULL;
    LSSharedFileListItemRef currentItem = NULL;
    
    [self copyLoginItems:&loginItems andCurrentLoginItem:&currentItem];
    
    if (loginItems) {
        if (value && currentItem == NULL) {
            GSLogDebug(@"Adding to startup items.");
            LSSharedFileListItemRef item = LSSharedFileListInsertItemURL(loginItems, kLSSharedFileListItemBeforeFirst, NULL, NULL, (__bridge CFURLRef)thePath, NULL, NULL);
            if (item) CFRelease(item);
        } else if (!value && currentItem != NULL) {
            GSLogDebug(@"Removing from startup items.");        
            LSSharedFileListItemRemove(loginItems, currentItem);
        }
        
        CFRelease(loginItems);
        if (currentItem)
            CFRelease(currentItem);
    }
}

@end
