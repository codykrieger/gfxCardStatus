//
//  systemProfiler.m
//  gfxCardStatus
//
//  Created by Cody Krieger on 4/22/10.
//  Copyright 2010 Cody Krieger. All rights reserved.
//

#import "systemProfiler.h"


@implementation systemProfiler

+ (BOOL)isUsingIntegratedGraphics:(id)sender {
	NSTask *task = [[NSTask alloc] init];
	[task setLaunchPath:@"/usr/sbin/system_profiler"];
	[task setArguments:[NSArray arrayWithObject:@"SPDisplaysDataType"]];
	
	NSPipe *pipe = [NSPipe pipe];
	[task setStandardOutput:pipe];
	
	NSFileHandle *file = [pipe fileHandleForReading];
	
	[task launch];
	[task waitUntilExit];
	
	NSData *data = [file readDataToEndOfFile];
	NSString *output = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
	
	NSArray *array = [output componentsSeparatedByString:@"\n"];
	
	NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
	NSMutableArray *currentKeys = [[NSMutableArray alloc] init];
	int currentLevel = 0;
	
	for (NSString *obj in array) {
		int lengthBeforeTrim = [obj length];
		int whitespaceLength = 0;
		obj = [obj stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
		whitespaceLength = lengthBeforeTrim - [obj length];
		
		if ([obj isEqualToString:@""]) {
			continue;
		}
		
		switch (whitespaceLength / 2) {
			case 0:
				// level 0
				currentLevel = 0;
				break;
			case 2:
				// level 1
				currentLevel = 1;
				break;
			case 3:
				// level 2
				currentLevel = 2;
				break;
			case 4:
				// level 3
				currentLevel = 3;
				break;
			case 5:
				// level 4
				currentLevel = 4;
				break;
			default:
				break;
		}
		
		while ([currentKeys count] > (currentLevel)) {
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
	
	//NSLog(@"dict!:\n%@", dict);
	
	NSDictionary *graphics = (NSDictionary *)[dict objectForKey:@"Graphics/Displays"];
	NSDictionary *integrated = (NSDictionary *)[graphics objectForKey:@"Intel HD Graphics"];
	if ([integrated isEqual:nil]) {
		integrated = (NSDictionary *)[graphics objectForKey:@"NVIDIA GeForce 9400M"];
	}
	NSDictionary *integratedDisplays = (NSDictionary *)[integrated objectForKey:@"Displays"];
	
	//NSDictionary *discrete = (NSDictionary *)[graphics objectForKey:@"NVIDIA GeForce GT 330M"];
	//NSDictionary *discreteDisplays = (NSDictionary *)[discrete objectForKey:@"Displays"];
	
	BOOL retval = NO;
	
	for (NSString *key in [integratedDisplays allKeys]) {
		NSDictionary *tempDict = (NSDictionary *)[integratedDisplays objectForKey:key];
		
		for (NSString *otherKey in [tempDict allKeys]) {
			if ([(NSString *)[tempDict objectForKey:otherKey] isEqualToString:@"No Display Connected"]) {
				retval = NO;
			} else {
				retval = YES;
			}
			break;
		}
		
		break;
	}
	
	return retval;
}

@end
