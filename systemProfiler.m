//
//  systemProfiler.m
//  gfxCardStatus
//
//  Created by Cody Krieger on 4/22/10.
//  Copyright 2010 Cody Krieger. All rights reserved.
//

#import "systemProfiler.h"

BOOL isUsingIntegratedGraphics(BOOL *legacy) {
    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath:@"/usr/sbin/system_profiler"];
    [task setArguments:[NSArray arrayWithObject:@"SPDisplaysDataType"]];
    
    NSPipe *pipe = [NSPipe pipe];
    [task setStandardOutput:pipe];
    
    [task launch];
    NSData *data = [[pipe fileHandleForReading] readDataToEndOfFile];
    [task waitUntilExit];
    [task release];
    
    NSString *output = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSArray *array = [output componentsSeparatedByString:@"\n"];
    [output release];
    
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
    NSMutableArray *currentKeys = [[NSMutableArray alloc] init];
    int currentLevel = 0;
    
    for (NSString *obj in array) {
        int lengthBeforeTrim = [obj length];
        int whitespaceLength = 0;
        obj = [obj stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        whitespaceLength = lengthBeforeTrim - [obj length];
        
        if ([obj isEqualToString:@""]) continue;
        if (whitespaceLength < 2) currentLevel = 0;
        else currentLevel = (whitespaceLength / 2) - 1;
        
        while ([currentKeys count] > currentLevel) {
            [currentKeys removeLastObject];
        }
        
        if ([obj hasSuffix:@":"]) {
            obj = [obj stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@":"]];
            
            if ([currentKeys count] == 0) {
                [dict setObject:[[NSMutableDictionary alloc] init] forKey: obj];
                [currentKeys addObject:obj];
            } else {
                NSMutableDictionary *tempDict = dict;
                for (int i = 0; i < [currentKeys count]; i++) {
                    tempDict = [tempDict objectForKey:[currentKeys objectAtIndex:i]];
                }
                
                [tempDict setObject:[[NSMutableDictionary alloc] init] forKey:obj];
                [currentKeys addObject:obj];
            }
            
            continue;
        } else {
            NSArray *tempArray = [obj componentsSeparatedByString:@": "];
            NSMutableDictionary *tempDict = dict; // = [dict objectForKey:currentKey];
            
            for (int i = 0; i < [currentKeys count]; i++) {
                tempDict = [tempDict objectForKey:[currentKeys objectAtIndex:i]];
            }
            
            [tempDict setObject:[NSString stringWithFormat:@"%@", [tempArray objectAtIndex:1]] forKey:[tempArray objectAtIndex:0]];
        }
    }
    
    NSDictionary *graphics = (NSDictionary *)[dict objectForKey:@"Graphics/Displays"];
    NSDictionary *integrated = (NSDictionary *)[graphics objectForKey:@"Intel HD Graphics"];
    
    if (!integrated) {
        if (legacy) *legacy = YES;
        integrated = (NSDictionary *)[graphics objectForKey:@"NVIDIA GeForce 9400M"];
        
        if (!integrated) {
            // display a message - must be using an unsupported model
            Log(@"*** UNSUPPORTED SYSTEM BEING USED ***");
            NSAlert *alert = [NSAlert alertWithMessageText:@"You are using a system that gfxCardStatus does not support. Please ensure that you are using a MacBook Pro with dual GPUs (15\" or 17\")." 
                              defaultButton:@"Oh, I see." alternateButton:nil otherButton:nil informativeTextWithFormat:@""];
            Log(@"runModal: %i", [alert runModal]);
        }
        
    } else {
        if (legacy) *legacy = NO;
    }
    
    NSDictionary *integratedDisplays = (NSDictionary *)[integrated objectForKey:@"Displays"];
    
    BOOL retval = NO;
    
    for (NSString *key in [integratedDisplays allKeys]) {
        NSDictionary *tempDict = (NSDictionary *)[integratedDisplays objectForKey:key];
        
        for (NSString *otherKey in [tempDict allKeys]) {
            retval = !([(NSString *)[tempDict objectForKey:otherKey] isEqualToString:@"No Display Connected"]);
            break;
        }
        if (retval) break;
    }
    
    [dict release];
    [currentKeys release];
    
    return retval;
}
