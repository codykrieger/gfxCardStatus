//
//  updateManager.m
//  gfxCardStatus
//
//  Created by Cody Krieger on 4/25/10.
//  Copyright 2010 Cody Krieger. All rights reserved.
//

#import "updateManager.h"
#import "JSON.h"

NSString *const ApplicationId = @"1";
NSString *const ApplicationVersion = @"1.0";
NSString *const ApplicationPrerelease = @"0";
NSString *const VersionUrl = @"http://codykrieger.com/versions?application_id=";

@implementation updateManager

+ (NSDictionary *)checkForUpdate {
	NSString *url = [NSString stringWithFormat:@"%@%@&prerelease=%@", VersionUrl, ApplicationId, ApplicationPrerelease];
	NSString *jsonString = [[NSString alloc] initWithContentsOfURL:[NSURL URLWithString:url] encoding:NSUTF8StringEncoding error:nil];
	id jsonValue = [jsonString JSONValue];
	[jsonString release];
	
	return jsonValue;
}

+ (void)update {
	NSDictionary *results = [self checkForUpdate];
	NSLog(@"%@", results);
	NSAlert *alert;
	if ([(NSString *)[results objectForKey:@"version"] isEqualToString:ApplicationVersion]) {
		// version strings are the same, we're up to date
		NSString *msg = [NSString stringWithFormat:@"gfxCardStatus is already up to date! (v%@)", ApplicationVersion];
		alert = [NSAlert alertWithMessageText:msg defaultButton:@"Cool!" alternateButton:nil otherButton:nil informativeTextWithFormat:@""];
		[alert runModal];
	} else {
		// a new version is available
		NSString *msg = [NSString stringWithFormat:@"gfxCardStatus v%@ is available! (You have v%@)", [results objectForKey:@"version"], ApplicationVersion];
		alert = [NSAlert alertWithMessageText:msg defaultButton:@"Get it!" alternateButton:@"Cancel" otherButton:nil informativeTextWithFormat:@""];
		if ([alert runModal] == NSAlertDefaultReturn) {
			// the user wants to download the new version!
			
		}
	}
}

@end
