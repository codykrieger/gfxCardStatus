//
//  GSGPU.m
//  gfxCardStatus
//
//  Created by Cody Krieger on 6/12/12.
//  Copyright (c) 2012 Cody Krieger. All rights reserved.
//

#import "GSGPU.h"
#import "GSMux.h"

#define kIOPCIDevice    "IOPCIDevice"
#define kIONameKey      "IOName"
#define kDisplayKey     "display"
#define kModelKey       "model"

static void displayReconfigurationCallback(CGDirectDisplayID display, CGDisplayChangeSummaryFlags flags, void *userInfo);

static NSMutableArray *gpus = nil;
static BOOL didCacheLegacyValue = NO;
static BOOL cachedLegacyValue = NO;
static id<GSGPUDelegate> delegate = nil;

@implementation GSGPU

+ (NSArray *)getGPUNames
{
    if (gpus) {
        return gpus;
    }
    
    gpus = [NSMutableArray array];
    
    // The IOPCIDevice class includes display adapters/GPUs.
    CFMutableDictionaryRef devices = IOServiceMatching(kIOPCIDevice);
    io_iterator_t entryIterator;
    
    if (IOServiceGetMatchingServices(kIOMasterPortDefault, devices, &entryIterator) == kIOReturnSuccess) {
        io_registry_entry_t device;
        
        while ((device = IOIteratorNext(entryIterator))) {
            CFMutableDictionaryRef serviceDictionary;
            
            if (IORegistryEntryCreateCFProperties(device, &serviceDictionary, kCFAllocatorDefault, kNilOptions) != kIOReturnSuccess) {
                // Couldn't get the properties for this service, so clean up and
                // continue.
                IOObjectRelease(device);
                continue;
            }
            
            const void *ioName = CFDictionaryGetValue(serviceDictionary, kIONameKey);
            
            if (ioName) {
                // If we have an IOName, and its value is "display", then we've
                // got a "model" key, whose value is a CFDataRef that we can
                // convert into a string.
                if (CFGetTypeID(ioName) == CFStringGetTypeID() && CFStringCompare(ioName, CFSTR(kDisplayKey), kCFCompareCaseInsensitive) == kCFCompareEqualTo) {
                    const void *model = CFDictionaryGetValue(serviceDictionary, @kModelKey);
                    
                    NSString *gpuName = [[NSString alloc] initWithData:(__bridge NSData *)model 
                                                              encoding:NSASCIIStringEncoding];
                    
                    [gpus addObject:gpuName];
                }
            }
            
            CFRelease(serviceDictionary);
        }
    }
    
    return gpus;
}

+ (NSString *)integratedGPUName
{
    // FIXME:
    return @"Integrated GPU";
}

+ (NSString *)discreteGPUName
{
    // FIXME:
    return @"Discrete GPU";
}

+ (BOOL)isLegacyMachine
{
    if (didCacheLegacyValue)
        return cachedLegacyValue;
    
    NSArray *gpuNames = [self getGPUNames];
    
    cachedLegacyValue = YES;
    for (NSString *name in gpuNames) {
        if (![name hasPrefix:@"NVIDIA"]) {
            cachedLegacyValue = NO;
            break;
        }
    }
    
    didCacheLegacyValue = YES;
    
    return cachedLegacyValue;
}

+ (void)registerForGPUChangeNotifications:(id<GSGPUDelegate>)object
{
    delegate = object;
    CGDisplayRegisterReconfigurationCallback(displayReconfigurationCallback, NULL);
}

static void displayReconfigurationCallback(CGDirectDisplayID display, CGDisplayChangeSummaryFlags flags, void *userInfo)
{
    if (flags & kCGDisplaySetModeFlag) {
        BOOL isUsingIntegrated = [GSMux isUsingIntegratedGPU];
        
        GTMLoggerInfo(@"Notification: GPU changed. Integrated? %d", isUsingIntegrated);
        
        GSGPUType activeType = (isUsingIntegrated ? GSGPUTypeIntegrated : GSGPUTypeDiscrete);
        [delegate gpuChangedTo:activeType];
    }
}

@end
