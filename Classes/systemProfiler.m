//
//  systemProfiler.m
//  gfxCardStatus
//
//  Created by Cody Krieger on 4/22/10.
//  Copyright 2010 Cody Krieger. All rights reserved.
//

#import "systemProfiler.h"

NSDictionary* getGraphicsProfile() {
    NSMutableDictionary *profile = [NSMutableDictionary dictionary];
    
    // call system_profiler SPDisplaysDataType in order to get GPU profile
    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath:@"/usr/sbin/system_profiler"];
    [task setArguments:[NSArray arrayWithObject:@"SPDisplaysDataType"]];
    
    NSPipe *pipe = [NSPipe pipe];
    [task setStandardOutput:pipe];
    
    [task launch];
    NSData *data = [[pipe fileHandleForReading] readDataToEndOfFile];
    [task waitUntilExit];
    [task release];
    
    // split up the output into lines
    NSString *output = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSArray *lines = [output componentsSeparatedByString:@"\n"];
    [output release];
    
    // parse the output into a dictionary of dictionaries based on section names,
    // which are determined by whitespace indentation level
    NSMutableDictionary *profilerInfo = [[NSMutableDictionary alloc] init];
    NSMutableArray *currentKeys = [[NSMutableArray alloc] init];
    int currentLevel = 0;
    
    for (NSString *obj in lines) {
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
                [profilerInfo setObject:[[[NSMutableDictionary alloc] init] autorelease] forKey: obj];
                [currentKeys addObject:obj];
            } else {
                NSMutableDictionary *tempDict = profilerInfo;
                for (int i = 0; i < [currentKeys count]; i++) {
                    tempDict = [tempDict objectForKey:[currentKeys objectAtIndex:i]];
                }
                
                [tempDict setObject:[[[NSMutableDictionary alloc] init] autorelease] forKey:obj];
                [currentKeys addObject:obj];
            }
            
            continue;
        } else {
            NSArray *tempArray = [obj componentsSeparatedByString:@": "];
            NSMutableDictionary *tempDict = profilerInfo; // = [dict objectForKey:currentKey];
            
            for (int i = 0; i < [currentKeys count]; i++) {
                tempDict = [tempDict objectForKey:[currentKeys objectAtIndex:i]];
            }
            
            [tempDict setObject:[NSString stringWithFormat:@"%@", [tempArray objectAtIndex:1]] forKey:[tempArray objectAtIndex:0]];
        }
    }
    
    // begin figuring out which machine we're using by attempting to get dictionaries
    // based on the integrated chipset names
    NSDictionary *graphics = (NSDictionary *)[profilerInfo objectForKey:@"Graphics/Displays"];
    NSDictionary *integrated = (NSDictionary *)[graphics objectForKey:@"Intel HD Graphics"];
    if (!integrated) integrated = (NSDictionary *)[graphics objectForKey:@"Intel HD Graphics 3000"];
    
    if (!integrated) {
        [profile setObject:[NSNumber numberWithBool:YES] forKey:@"legacy"];
        integrated = (NSDictionary *)[graphics objectForKey:@"NVIDIA GeForce 9400M"];
        
        if (!integrated) {
            // display a message - must be using an unsupported model
            Log(@"*** UNSUPPORTED SYSTEM BEING USED ***");
            [profile setObject:[NSNumber numberWithBool:YES] forKey:@"unsupported"];
        } else {
            [profile setObject:[NSNumber numberWithBool:NO] forKey:@"unsupported"];
        }
    } else {
        [profile setObject:[NSNumber numberWithBool:NO] forKey:@"legacy"];
        [profile setObject:[NSNumber numberWithBool:NO] forKey:@"unsupported"];
    }
    
    // figure out whether or not we're using the integrated GPU
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
    
    // if we're using an unsupported machine config, set profile values to empty strings just in case
    // otherwise, set the integrated and discrete GPU names in the profile, as well as whether or not
    // we're using the integrated GPU
    if ([[profile objectForKey:@"unsupported"] boolValue]) {
        [profile setObject:@"" forKey:@"integratedString"];
        [profile setObject:@"" forKey:@"discreteString"];
        [profile setObject:@"" forKey:@"usingIntegrated"];
    } else {
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
    }
    
    [profilerInfo release];
    [currentKeys release];
    
    return profile;
}
