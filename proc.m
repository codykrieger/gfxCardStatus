//
//  proc.m
//  gfxCardStatus
//
//  Created by Thierry Coppey on 14.05.10.
//  Copyright 2010 Thierry Coppey. All rights reserved.
//

#import "proc.h"

#include <CoreFoundation/CoreFoundation.h>
#include <IOKit/IOKitLib.h>
#include <sys/sysctl.h>
#include <unistd.h>

static const CFStringRef procTaskKey = (const CFStringRef)__builtin___CFStringMakeConstantString("task-list");

static mach_port_t procPort = 0;
static struct kinfo_proc *procInfo = NULL;
static size_t procSize = 0;
static size_t procNum = 0;

static void procUpdate() {
	int mib[3] = {CTL_KERN, KERN_PROC, KERN_PROC_ALL};
	struct kinfo_proc* info = NULL;
	size_t sz;

	if (sysctl(mib,3,NULL,&sz,NULL,0)<0) return;
	
	if (procInfo == NULL || sz != procSize) {
		info = realloc(procInfo, sz);
		if (info == NULL) return;
		procInfo = info; procSize = sz;
	}
	
	if (sysctl(mib,3,procInfo,&sz,NULL,0)<0) return;
	procNum = sz/sizeof(struct kinfo_proc);
}

static void procTask(const void * value, void * param) {
	NSMutableDictionary* dict = (NSMutableDictionary*)param;
	NSNumber *key = NULL;
	NSString *val = NULL;
	NSString *procName = NULL;
	
	int mib[3] = {CTL_KERN, KERN_ARGMAX, 0};
	struct kinfo_proc* k = NULL;
	size_t n, sz;
	long long pid;
	char *buf, *sp, *cp;

	if (procInfo == NULL) return;
	if (!CFNumberGetValue(value, kCFNumberLongLongType, &pid)) return;
	
	for (n=0; n<procNum; n++) {
		if (procInfo[n].kp_proc.p_pid == pid) {
			k = &procInfo[n];
			break;
		}
	}
	if (k==NULL) return;

	key = [[NSNumber alloc] initWithLongLong:pid];
	
	sz = sizeof(n);
	if (sysctl(mib, 2, &n, &sz, NULL, 0) == -1) goto err;
	
	buf = (char*)malloc(n);
	if (buf == NULL) goto err;
	
	mib[1] = KERN_PROCARGS2;
	mib[2] = k->kp_proc.p_pid;
	
	sz = (size_t)n;
	if (sysctl(mib, 3, buf, &sz, NULL, 0) == -1) {
		free(buf);
		goto err;
	}
	
	cp = buf + sizeof(int);
	if ((sp=strrchr(cp,'/'))) cp = sp+1;
	
	procName = [[NSString alloc] initWithUTF8String:cp];
	val = [NSString stringWithFormat:@"%@, PID: %@", procName, [key stringValue]];
	free(buf);
	goto add;
err:
	val = [[NSString alloc] initWithUTF8String:k->kp_proc.p_comm];
add:
	[dict setObject:val forKey:key];
	[key release]; [procName release];
}

static void procScan(io_registry_entry_t service, NSMutableDictionary* dict) {
	io_registry_entry_t child	 = 0;
	io_iterator_t		children = 0;
	CFMutableDictionaryRef props = NULL;
	
	if (IOObjectConformsTo(service, "AppleGraphicsControl")) {
		kern_return_t status = IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, kNilOptions);
		if (status == KERN_SUCCESS && CFGetTypeID(props) == CFDictionaryGetTypeID()) {
			CFTypeRef array = CFDictionaryGetValue(props, procTaskKey);
			CFRange range = { 0, CFArrayGetCount(array) };
			[dict removeAllObjects];
			CFArrayApplyFunction(array, range, procTask, dict);
			CFRelease(props);
		}
	}
	
	if (IORegistryEntryGetChildIterator(service, kIOPowerPlane, &children) == KERN_SUCCESS) { // kIOServicePlane
		while ((child = IOIteratorNext(children))) {
			procScan(child, dict);
			IOObjectRelease(child);
		}
		IOObjectRelease(children);
	}
}

BOOL procInit() {
	return IOMasterPort(bootstrap_port, &procPort) == KERN_SUCCESS;
}

void procFree() {
	free(procInfo);
	procInfo = NULL;
}

BOOL procGet(NSMutableDictionary* dict) {
	io_registry_entry_t service = 0;
	if (dict == NULL) return NO;
	
	service = IORegistryGetRootEntry(procPort);
	if (!service) return NO;
	
	procUpdate();
	procScan(service, dict);
	IOObjectRelease(service);
	return YES;
}
