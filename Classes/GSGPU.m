//
//  GSGPU.m
//  gfxCardStatus
//
//  Created by Cody Krieger on 6/12/12.
//  Copyright (c) 2012 Cody Krieger. All rights reserved.
//

#import "GSGPU.h"
#import "GSMux.h"

#define kIOPCIDevice                "IOPCIDevice"
#define kIONameKey                  "IOName"
#define kDisplayKey                 "display"
#define kModelKey                   "model"

#define kIntelGPUPrefix             @"Intel"

#define kLegacyIntegratedGPUName    @"NVIDIA GeForce 9400M"
#define kLegacyDiscreteGPUName      @"NVIDIA GeForce 9600M GT"

#define kNotificationQueueName      "com.codykrieger.gfxCardStatus.GPUChangeNotificationQueue"
#define kNotificationSleepInterval  (0.5)

static void _displayReconfigurationCallback(CGDirectDisplayID display, CGDisplayChangeSummaryFlags flags, void *userInfo);
static dispatch_queue_t _notificationQueue = NULL;

static NSMutableArray *_cachedGPUs = nil;
static NSString *_cachedIntegratedGPUName = nil;
static NSString *_cachedDiscreteGPUName = nil;

static BOOL _didCacheLegacyValue = NO;
static BOOL _cachedLegacyValue = NO;

static id<GSGPUDelegate> _delegate = nil;

#pragma mark - Static C methods

static void _displayReconfigurationCallback(CGDirectDisplayID display, CGDisplayChangeSummaryFlags flags, void *userInfo)
{
    // If we got a display reconfiguration callback for a display that's not
    // built-in, we should probably just kick the user over to Dynamic Switching
    // if they're on a non-legacy machine. Not sure how often this method will
    // be called with a non-built-in CGDirectDisplayID, so we should make sure
    // we aren't just randomly changing modes on users unexpectedly. Need to do
    // some testing of this before the v2.2/v2.3 release.
    if (!CGDisplayIsBuiltin(display) && ![GSGPU isLegacyMachine]) {
        // FIXME: Implement. This kind of needs to happen.
    }
    
    if (flags & kCGDisplaySetModeFlag) {
        dispatch_async(_notificationQueue, ^(void) {
            [NSThread sleepForTimeInterval:kNotificationSleepInterval];
            
            BOOL isUsingIntegrated = [GSMux isUsingIntegratedGPU];
            
            GTMLoggerInfo(@"Notification: GPU changed. Integrated? %d", isUsingIntegrated);
            
            GSGPUType activeType = (isUsingIntegrated ? GSGPUTypeIntegrated : GSGPUTypeDiscrete);
            [_delegate GPUDidChangeTo:activeType];
        });
    }
}

@implementation GSGPU

#pragma mark - GSGPU API

+ (NSArray *)getGPUNames
{
    if (_cachedGPUs)
        return _cachedGPUs;
    
    _cachedGPUs = [NSMutableArray array];
    
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
                    
                    [_cachedGPUs addObject:gpuName];
                }
            }
            
            CFRelease(serviceDictionary);
        }
    }
    
    return _cachedGPUs;
}

+ (NSString *)integratedGPUName
{
    if (_cachedIntegratedGPUName)
        return _cachedIntegratedGPUName;
    
    if ([self isLegacyMachine]) {
        _cachedIntegratedGPUName = kLegacyIntegratedGPUName;
    } else {
        NSArray *gpus = [self getGPUNames];
        
        for (NSString *gpu in gpus) {
            // Intel GPUs have always been the integrated ones in newer machines
            // so far.
            if ([gpu hasPrefix:kIntelGPUPrefix]) {
                _cachedIntegratedGPUName = gpu;
                break;
            }
        }
    }
    
    return _cachedIntegratedGPUName;
}

+ (NSString *)discreteGPUName
{
    if (_cachedDiscreteGPUName)
        return _cachedDiscreteGPUName;
    
    if ([self isLegacyMachine]) {
        _cachedDiscreteGPUName = kLegacyDiscreteGPUName;
    } else {
        NSArray *gpus = [self getGPUNames];
        
        for (NSString *gpu in gpus) {
            // Check for the GPU name that *doesn't* start with Intel, so that
            // both AMD and NVIDIA GPUs get detected here.
            if (![gpu hasPrefix:kIntelGPUPrefix]) {
                _cachedDiscreteGPUName = gpu;
                break;
            }
        }
    }
    
    return _cachedDiscreteGPUName;
}

+ (BOOL)isLegacyMachine
{
    if (_didCacheLegacyValue)
        return _cachedLegacyValue;
    
    NSArray *gpuNames = [self getGPUNames];
    
    _cachedLegacyValue = [gpuNames containsObject:kLegacyIntegratedGPUName]
                        && [gpuNames containsObject:kLegacyDiscreteGPUName];
    
    _didCacheLegacyValue = YES;
    
    return _cachedLegacyValue;
}

+ (void)registerForGPUChangeNotifications:(id<GSGPUDelegate>)object
{
    _delegate = object;
    _notificationQueue = dispatch_queue_create(kNotificationQueueName, NULL);
    CGDisplayRegisterReconfigurationCallback(_displayReconfigurationCallback, NULL);
}

+ (void)fireManualChangeNotification
{
    _displayReconfigurationCallback(CGMainDisplayID(), kCGDisplaySetModeFlag, NULL);
}

@end
