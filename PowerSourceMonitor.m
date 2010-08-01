//
//  PowerSourceMonitor.m
//  gfxCardStatus
//
//  Created by softboysxp on 10/05/16.
//  Copyright 2010 softboysxp. All rights reserved.
//

#import "PowerSourceMonitor.h"

#include <IOKit/IOKitLib.h>
#include <IOKit/ps/IOPSKeys.h>
#include <IOKit/ps/IOPowerSources.h>

static BOOL stringsAreEqual(CFStringRef a, CFStringRef b) {
	if (a == nil || b == nil) {
		return NO;
	}
	
	return (CFStringCompare (a, b, 0) == kCFCompareEqualTo);
}

static PowerSource getCurrentPowerSource() {
	PowerSource status = psUnknown;
	
	CFTypeRef blob = IOPSCopyPowerSourcesInfo();
	CFArrayRef list = IOPSCopyPowerSourcesList(blob);
	
	int count = CFArrayGetCount(list);
	
	if (count == 0) {
		status = psACAdaptor;
		goto cleanup;
	}
	
	for (int i = 0; i < count; i++) {
		CFTypeRef source;
		CFDictionaryRef description;
		
		source = CFArrayGetValueAtIndex(list, i);
		description = IOPSGetPowerSourceDescription(blob, source);
		
		if (stringsAreEqual(CFDictionaryGetValue(description, CFSTR (kIOPSTransportTypeKey)), CFSTR (kIOPSInternalType))) {
			CFStringRef currentState = CFDictionaryGetValue(description, CFSTR (kIOPSPowerSourceStateKey));
			
			if (stringsAreEqual(currentState, CFSTR (kIOPSACPowerValue))) {
				status = psACAdaptor;
			} else if (stringsAreEqual(currentState, CFSTR (kIOPSBatteryPowerValue))) {
				status = psBattery;
			} else {
				status = psUnknown;
			}
			// Add charge code once thresholding code is implemented.
		} 
	}
	
cleanup:
	CFRelease (list);
	CFRelease (blob);
	
	return status;
}


void powerSourceChanged(void * context) {
	PowerSourceMonitor *powerSourceMonitor = (PowerSourceMonitor *) context;
	
	[powerSourceMonitor powerSourceChanged:getCurrentPowerSource()];
}

void registerPowerSourceNotification(PowerSourceMonitor *powerSourceMonitor) {
	CFRunLoopSourceRef loopSource = IOPSNotificationCreateRunLoopSource(powerSourceChanged, powerSourceMonitor);
	
	if (loopSource) {
		CFRunLoopAddSource(CFRunLoopGetCurrent(), loopSource, kCFRunLoopDefaultMode);
	} else {
		NSLog(@"Creating RunLoop failed!\n");
	}
	
	CFRelease (loopSource);
}

@implementation PowerSourceMonitor

@synthesize delegate;

- (void)powerSourceChanged:(PowerSource)powerSource {
	if ([delegate respondsToSelector:@selector(powerSourceChanged:)]) {
		[delegate powerSourceChanged:powerSource];
	}
}

- (PowerSourceMonitor *)initWithDelegate:(id<PowerSourceMonitorDelegate>)__delegate {
	if (self = [super init]) {
		self.delegate = __delegate;
		
		registerPowerSourceNotification([self retain]);
	}
	
	return self;
}

+ (PowerSourceMonitor *)monitorWithDelegate:(id<PowerSourceMonitorDelegate>)__delegate {
	return [[[self alloc] initWithDelegate:__delegate] autorelease];
}
		 
- (PowerSource)currentPowerSource {
	return getCurrentPowerSource();
}

@end
