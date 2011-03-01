//
//  systemProfiler.m
//  gfxCardStatus
//
//  Created by Cody Krieger on 4/22/10.
//  Copyright 2010 Cody Krieger. All rights reserved.
//

#import "systemProfiler.h"

NSDictionary* getGraphicsProfile(BOOL throwExceptionIfUnsupportedSystem) {
    NSMutableDictionary *profile = [NSMutableDictionary dictionary];
    
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
                [dict setObject:[[[NSMutableDictionary alloc] init] autorelease] forKey: obj];
                [currentKeys addObject:obj];
            } else {
                NSMutableDictionary *tempDict = dict;
                for (int i = 0; i < [currentKeys count]; i++) {
                    tempDict = [tempDict objectForKey:[currentKeys objectAtIndex:i]];
                }
                
                [tempDict setObject:[[[NSMutableDictionary alloc] init] autorelease] forKey:obj];
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
    if (!integrated) integrated = (NSDictionary *)[graphics objectForKey:@"Intel HD Graphics 3000"];
    
    if (!integrated) {
        [profile setObject:[NSNumber numberWithBool:YES] forKey:@"legacy"];
        integrated = (NSDictionary *)[graphics objectForKey:@"NVIDIA GeForce 9400M"];
        
        if (!integrated) {
            // display a message - must be using an unsupported model
            Log(@"*** UNSUPPORTED SYSTEM BEING USED ***");
            
            if (throwExceptionIfUnsupportedSystem) {
                NSException *exception = [NSException exceptionWithName:@"UnsupportedMachineException" reason:@"An unsupported machine is being used." userInfo:nil];
                @throw exception;
            }
        }
        
    } else {
        [profile setObject:[NSNumber numberWithBool:NO] forKey:@"legacy"];
    }
    
    NSDictionary *integratedDisplays = (NSDictionary *)[integrated objectForKey:@"Displays"];
    
    BOOL usingIntegrated = NO;
    
    for (NSString *key in [integratedDisplays allKeys]) {
        NSDictionary *tempDict = (NSDictionary *)[integratedDisplays objectForKey:key];
        
        for (NSString *otherKey in [tempDict allKeys]) {
            usingIntegrated = !([(NSString *)[tempDict objectForKey:otherKey] isEqualToString:@"No Display Connected"]);
            break;
        }
        if (usingIntegrated) break;
    }
    
    NSEnumerator *keys = [graphics keyEnumerator];
    NSString *key;
    while ((key = (NSString *)[keys nextObject])) {
        if ([[key stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] isEqualToString:@""]) continue;
        
        if ([key isEqualToString:@"Intel HD Graphics"] || 
            [key isEqualToString:@"Intel HD Graphics 3000"] || 
            [key isEqualToString:@"NVIDIA GeForce 9400M"]) {
            [profile setObject:key forKey:@"integratedString"];
        } else {
            [profile setObject:key forKey:@"discreteString"];
        }
    }
    
    [profile setObject:[NSNumber numberWithBool:usingIntegrated] forKey:@"usingIntegrated"];
    
    [dict release];
    [currentKeys release];
    
    return profile;
}
