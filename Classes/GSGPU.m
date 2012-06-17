//
//  GSGPU.m
//  gfxCardStatus
//
//  Created by Cody Krieger on 6/12/12.
//  Copyright (c) 2012 Cody Krieger. All rights reserved.
//

#import "GSGPU.h"
#import "GSMux.h"

#define kIOPCIDevice        "IOPCIDevice"
#define kIONameKey          "IOName"
#define kIOChildIndexKey    "IOChildIndex"
#define kDisplayKey         "display"
#define kModelKey           "model"

#define kIntelGPUPrefix     "Intel"

#define kLegacyIntegratedGPUName "NVIDIA GeForce 9400M"
#define kLegacyDiscreteGPUName "NVIDIA GeForce 9600M GT"

static void displayReconfigurationCallback(CGDirectDisplayID display, CGDisplayChangeSummaryFlags flags, void *userInfo);

static NSMutableArray *cachedGPUs = nil;
static NSString *cachedIntegratedGPUName = nil;
static NSString *cachedDiscreteGPUName = nil;
static BOOL didCacheLegacyValue = NO;
static BOOL cachedLegacyValue = NO;
static id<GSGPUDelegate> delegate = nil;

@implementation GSGPU

+ (NSArray *)getGPUNames
{
    if (cachedGPUs) {
        return cachedGPUs;
    }
    
    cachedGPUs = [NSMutableArray array];
    
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
            
            const void *ioName = CFDictionaryGetValue(serviceDictionary, @kIONameKey);
            
            if (ioName) {
                // If we have an IOName, and its value is "display", then we've
                // got a "model" key, whose value is a CFDataRef that we can
                // convert into a string.
                if (CFGetTypeID(ioName) == CFStringGetTypeID() && CFStringCompare(ioName, CFSTR(kDisplayKey), kCFCompareCaseInsensitive) == kCFCompareEqualTo) {
                    const void *model = CFDictionaryGetValue(serviceDictionary, @kModelKey);
                    
                    NSString *gpuName = [[NSString alloc] initWithData:(__bridge NSData *)model 
                                                              encoding:NSASCIIStringEncoding];
                    
                    [cachedGPUs addObject:gpuName];
                }
            }
            
            CFRelease(serviceDictionary);
        }
    }
    
    return cachedGPUs;
}

+ (NSString *)integratedGPUName
{
    if (cachedIntegratedGPUName)
        return cachedIntegratedGPUName;
    
    if ([self isLegacyMachine]) {
        cachedIntegratedGPUName = @kLegacyIntegratedGPUName;
    } else {
        NSArray *gpus = [self getGPUNames];
        
        for (NSString *gpu in gpus) {
            // Intel GPUs have always been the integrated ones in newer machines
            // so far.
            if ([gpu hasPrefix:@kIntelGPUPrefix]) {
                cachedIntegratedGPUName = gpu;
                break;
            }
        }
    }
    
    return cachedIntegratedGPUName;
}

+ (NSString *)discreteGPUName
{
    if (cachedDiscreteGPUName)
        return cachedDiscreteGPUName;
    
    if ([self isLegacyMachine]) {
        cachedDiscreteGPUName = @kLegacyDiscreteGPUName;
    } else {
        NSArray *gpus = [self getGPUNames];
        
        for (NSString *gpu in gpus) {
            // Check for the GPU name that *doesn't* start with Intel, so that
            // both AMD and NVIDIA GPUs get detected here.
            if (![gpu hasPrefix:@kIntelGPUPrefix]) {
                cachedDiscreteGPUName = gpu;
                break;
            }
        }
    }
    
    return cachedDiscreteGPUName;
}

+ (BOOL)isLegacyMachine
{
    if (didCacheLegacyValue)
        return cachedLegacyValue;
    
    NSArray *gpuNames = [self getGPUNames];
    
    cachedLegacyValue = [gpuNames containsObject:@kLegacyIntegratedGPUName]
                        && [gpuNames containsObject:@kLegacyDiscreteGPUName];
    
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
