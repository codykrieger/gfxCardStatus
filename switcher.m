//
//  switcher.m
//  gfxCardStatus
//
//  Created by Cody Krieger on 5/7/10.
//  95% of the following code was written by ah. I have only modified and customized it to better fit
//  the purpose of gfxCardStatus.
//

#import "switcher.h"
#include <IOKit/IOKitLib.h>
#include <ApplicationServices/ApplicationServices.h>
#import "gfxCardStatusAppDelegate.h"

#define kDriverClassName "AppleGraphicsControl"
#define kForceIntel 0
#define kForceNvidia 1
#define kEnableSwitchingMode 2

// Stuff to look at:
// nvram -p -> gpu_policy
// bootargs: agc=0/1: flags in dmesg
// Compile: gcc -o switcher switcher.c -framework IOKit
// Enable logging to kernel.log:
// Add agclog=10000 agcdebug=4294967295 to com.apple.Boot.plist

// User client method dispatch selectors.
enum {
    kOpen,
    kClose,
    kSetMuxState,
    kGetMuxState,
    kSetExclusive,
    kDumpState,
    kUploadEDID,
    kGetAGCData,
    kGetAGCData_log1,
    kGetAGCData_log2,
    kNumberOfMethods
};

enum SetMuxStates {
    // See FeatureInfos
    SetDisableFeatureInfo,
    SetEnableFeatureInfo,
    SetForceSwitch, // Force Graphics Switch regardless of switching mode
    SetPowerChangeGPU, // power down a gpu, pretty useless since you can't power down the igp and the dedicated gpu is powered down automatically
    // The same as if you click the checkbox in systemsettings.app
    SetGpuSelect, // = Dynamic Switching on/off with [2] = 0/1
    // TODO: Test what happens on older mbps when switchpolicy = 0
    // Changes if you're able to switch in systemsettings.app without logout
    SetSwitchPolicy // 0 = dynamic switching, 2 = no dynamic switching, exactly like older mbp switching, 3 = no dynamic stuck, others unsupported
};

enum GetMuxStates {
    GetFeatureInfo, // Returns a uint64_t with bits set according to FeatureInfos, 1=enabled
    GetFeatureInfo2, // The same as GetFeatureInfo
    Unknown, // always returns 0xdeadbeef
    GetPoweredOnGPUs, // maybe returns powered on graphics cards, 0x8 = Intel, 0x88 = Nvidia (or probably both, since Intel never gets powered down?)
    GetGpuSelect, // see SetMuxStates
    GetSwitchPolicy, // see SetMuxStates, possibly inverted?
    Unknown2, // always 0xdeadbeef
    GetGraphicsCard, // returns active graphics card
    Unknown3 // sometimes 0xffffffff, TODO: figure out what that means
};

enum FeatureInfos {
    Policy,
    Auto_PowerDown_GPU,
    Dynamic_Switching,
    GPU_Powerpolling, // Inverted: Disable Feature enables it and vice versa
    Defer_Policy,
    Synchronous_Launch,
    Backlight_Control=8,
    Recovery_Timeouts,
    Power_Switch_Debounce,
    Logging=16,
    Display_Capture_Switch,
    No_GL_HDA_busy_idle_registration,
    NumberFeatureInfos
};

char* getFeatureInfoName(int arg)
{
    switch (arg) {
        case Policy: return "Policy";
        case Auto_PowerDown_GPU: return "Auto_PowerDown_GPU";
        case Dynamic_Switching: return "Dynamic_Switching";
        case GPU_Powerpolling: return "GPU_Powerpolling";
        case Defer_Policy: return "Defer_Policy";
        case Synchronous_Launch: return "Synchronous_Launch";
        case Backlight_Control: return "Backlight_Control";
        case Recovery_Timeouts: return "Recovery_Timeouts";
        case Power_Switch_Debounce: return "Power_Switch_Debounce";
        case Logging: return "Logging";
        case Display_Capture_Switch: return "Display_Capture_Switch";
        case No_GL_HDA_busy_idle_registration: return "No_GL_HDA_busy_idle_registration";
        default: return "Unknown Feature";
    }
}

kern_return_t OpenDriverConnection(io_service_t service, io_connect_t *connect)
{
    // This call will cause the user client to be instantiated. It returns an io_connect_t handle
    // that is used for all subsequent calls to the user client.
    // Applications pass the bad-Bit (indicates they need the dedicated gpu here)
    // as uint32_t type, 0 = no dedicated gpu, 1 = dedicated
    kern_return_t kernResult = IOServiceOpen(service, mach_task_self(), 0, connect);
    
    if (kernResult != KERN_SUCCESS) {
        fprintf(stderr, "IOServiceOpen returned 0x%08x\n", kernResult);
    }
    else {
        kern_return_t    kernResult;
        kernResult = IOConnectCallScalarMethod(*connect, kOpen, NULL, 0, NULL, NULL);
        return kernResult;
        
        if (kernResult == KERN_SUCCESS) {
            printf("OpenDriverConnection was successful.\n\n");
        }
        else {
            fprintf(stderr, "OpenDriverConnection returned 0x%08x.\n\n", kernResult);
        }
    }
    
    return kernResult;
}


void CloseDriverConnection(io_connect_t connect)
{
    kern_return_t    kernResult;
    kernResult = IOConnectCallScalarMethod(connect, kClose, NULL, 0, NULL, NULL);
    
    if (kernResult == KERN_SUCCESS) {
        printf("CloseDriverConnection was successful.\n\n");
    }
    else {
        fprintf(stderr, "CloseDriverConnection returned 0x%08x.\n\n", kernResult);
    }
    
    kernResult = IOServiceClose(connect);
    
    if (kernResult == KERN_SUCCESS) {
        printf("IOServiceClose was successful.\n\n");
    }
    else {
        fprintf(stderr, "IOServiceClose returned 0x%08x\n\n", kernResult);
    }
}

kern_return_t getMuxState(io_connect_t connect, uint64_t input, uint64_t *output)
{
    kern_return_t kernResult;
    
    uint64_t    scalarI_64[2];
    uint32_t    outputCount = 1; 
    
    scalarI_64[0] = 1; // Always 1 (kMuxControl?)
    scalarI_64[1] = input; // Feature Info
    
    kernResult = IOConnectCallScalarMethod(connect,                    // an io_connect_t returned from IOServiceOpen().
                                           kGetMuxState,            // selector of the function to be called via the user client.
                                           scalarI_64,                // array of scalar (64-bit) input values.
                                           2,                        // the number of scalar input values.
                                           output,                // array of scalar (64-bit) output values.
                                           &outputCount                // pointer to the number of scalar output values.
                                           );
    
    if (kernResult == KERN_SUCCESS) {
        printf("getMuxState was successful.\n");
        printf("outputCount = %d\n", outputCount);
        printf("resultNumber = 0x%08llx\n\n", *output);
    }
    else {
        fprintf(stderr, "getMuxState returned 0x%08x.\n\n", kernResult);
    }
    
    return kernResult;
}

void setMuxState(io_connect_t connect, enum SetMuxStates state, uint64_t arg)
{
    kern_return_t kernResult;
    
    uint64_t    scalarI_64[3];
    
    scalarI_64[0] = 1; // always?
    scalarI_64[1] = (uint64_t) state;
    scalarI_64[2] = arg;
    
    kernResult = IOConnectCallScalarMethod(connect,                    // an io_connect_t returned from IOServiceOpen().
                                           kSetMuxState,            // selector of the function to be called via the user client.
                                           scalarI_64,                // array of scalar (64-bit) input values.
                                           3,                        // the number of scalar input values.
                                           NULL,                // array of scalar (64-bit) output values.
                                           0                // pointer to the number of scalar output values.
                                           );
    
    if (kernResult == KERN_SUCCESS) {
        printf("setMuxState was successful.\n\n");
    }
    else {
        fprintf(stderr, "setMuxState returned 0x%08x.\n\n", kernResult);
    }
}

void setFeatureInfoEnabled(io_connect_t connect, uint64_t feature, int enabled)
{
    if (enabled)
        setMuxState(connect, SetEnableFeatureInfo, 1<<feature);
    else 
        setMuxState(connect, SetDisableFeatureInfo, 1<<feature);
}

int getFeatureInfoEnabled(io_connect_t connect, uint64_t arg)
{
    uint64_t featureInfo;
    featureInfo = 0;
    getMuxState(connect, GetFeatureInfo, &featureInfo);
    return ((1<<arg) & featureInfo) || 0;
}

void printFeatures(io_connect_t connect)
{
    uint64_t featureInfo;
    featureInfo = 0;
    getMuxState(connect, GetFeatureInfo, &featureInfo);
    enum FeatureInfos f = Policy;
    for (; f < 19; f++) {
        printf("%s: %s\n", getFeatureInfoName(f), (featureInfo & (1<<f) ? "enabled" : "disabled"));
    }
}

// arg = 2: user needs to logout before switching, arg = 0: instant switching
void setSwitchPolicy(io_connect_t connect, int arg)
{
    if (arg)
        setMuxState(connect, SetSwitchPolicy, 0);
    else
        setMuxState(connect, SetSwitchPolicy, 2);
}

// The same as clicking the checkbox in systemsettings.app
void setDynamicSwitchingEnabled(io_connect_t connect, int enabled)
{
    if (enabled)
        setMuxState(connect, SetGpuSelect, 1);
    else
        setMuxState(connect, SetGpuSelect, 0);
}

// switch graphic cards now regardless of switching mode
void forceSwitch(io_connect_t connect)
{
    setMuxState(connect, SetForceSwitch, 0);
}

// ???
void setExclusive(io_connect_t connect)
{
    kern_return_t kernResult;
    
    uint64_t    scalarI_64[1];
    
    scalarI_64[0] = 0x0;
    
    kernResult = IOConnectCallScalarMethod(connect,                    // an io_connect_t returned from IOServiceOpen().
                                           kSetExclusive,            // selector of the function to be called via the user client.
                                           scalarI_64,                // array of scalar (64-bit) input values.
                                           1,                        // the number of scalar input values.
                                           NULL,                // array of scalar (64-bit) output values.
                                           0                // pointer to the number of scalar output values.
                                           );
    
    if (kernResult == KERN_SUCCESS) {
        printf("setExclusive was successful.\n\n");
    }
    else {
        fprintf(stderr, "setExclusive returned 0x%08x.\n\n", kernResult);
    }
}

typedef struct StateStruct {
    uint32_t field1[25]; // State Struct has to be 100 bytes long
} StateStruct;

void dumpState(io_connect_t connect)
{
    kern_return_t kernResult;
    
    StateStruct        stateStruct;
    size_t            structSize = sizeof(StateStruct);
    
    kernResult = IOConnectCallMethod(connect,                        // an io_connect_t returned from IOServiceOpen().
                                     kDumpState,                    // selector of the function to be called via the user client.
                                     NULL,                            // array of scalar (64-bit) input values.
                                     0,                                // the number of scalar input values.
                                     NULL,                            // a pointer to the struct input parameter.
                                     0,                                // the size of the input structure parameter.
                                     NULL,                            // array of scalar (64-bit) output values.
                                     NULL,                            // pointer to the number of scalar output values.
                                     &stateStruct,                    // pointer to the struct output parameter.
                                     &structSize                    // pointer to the size of the output structure parameter.
                                     );
    
    // TODO: figure the meaning of the values in StateStruct out
    
    if (kernResult == KERN_SUCCESS) {
        printf("setExclusive was successful.\n\n");
    }
    else {
        fprintf(stderr, "setExclusive returned 0x%08x.\n\n", kernResult);
    }
}

// returns 1 if nvidia is active and 0 if intel is active
int getActiveCard(connect) {
    uint64_t output;
    getMuxState(connect, GetGraphicsCard, &output);
    return !(output);
}

void setAlwaysIntel(connect) {
    setDynamicSwitchingEnabled(connect, 0);
    // Disable Policy, otherwise gpu switches to Nvidia after a bad app closes
    setFeatureInfoEnabled(connect, Policy, 0);
    sleep(1);
    
    if (getActiveCard(connect))
        forceSwitch(connect);
}

void setAlwaysNvidia(connect) {
    setDynamicSwitchingEnabled(connect, 0);
    setFeatureInfoEnabled(connect, Policy, 0);
    sleep(1);
    
    if (!getActiveCard(connect))
        forceSwitch(connect);
}

void setDynamicSwitching(connect) {
    setFeatureInfoEnabled(connect, Policy, 1);
    setDynamicSwitchingEnabled(connect, 1);
}

void UseDevice(io_service_t service, int mode)
{
    kern_return_t                kernResult;
    io_connect_t                connect;
    
    // Instantiate a connection to the user client.
    kernResult = OpenDriverConnection(service, &connect);
    
    if (connect != IO_OBJECT_NULL) {
        
		switch (mode)
		{
			case kForceIntel:
				setAlwaysIntel(connect);
				break;
			case kForceNvidia:
				setAlwaysNvidia(connect);
				break;
			case kEnableSwitchingMode:
				setDynamicSwitching(connect);
				break;
		}

        CloseDriverConnection(connect);
    }
}

int runSwitcher(int mode) {
	kern_return_t    kernResult; 
    io_service_t    service;
    io_iterator_t     iterator;
    bool            driverFound = false;
    
    // Look up the objects we wish to open.     
    // This creates an io_iterator_t of all instances of our driver that exist in the I/O Registry.
    kernResult = IOServiceGetMatchingServices(kIOMasterPortDefault, IOServiceMatching(kDriverClassName), &iterator);
    
    if (kernResult != KERN_SUCCESS) {
        fprintf(stderr, "IOServiceGetMatchingServices returned 0x%08x\n\n", kernResult);
        return -1;
    }
    
    while ((service = IOIteratorNext(iterator)) != IO_OBJECT_NULL) {
        driverFound = true;
        printf("Found a device of class "kDriverClassName".\n\n");
        UseDevice(service ,mode);
    }
    
    // Release the io_iterator_t now that we're done with it.
    IOObjectRelease(iterator);
    
    if (driverFound == false) {
        fprintf(stderr, "No matching drivers found.\n");
    }
    
    return EXIT_SUCCESS;
}

@implementation switcher

+ (void)forceIntel {
	runSwitcher(kForceIntel);
}

+ (void)forceNvidia {
	runSwitcher(kForceNvidia);
}

+ (void)dynamicSwitching {
	runSwitcher(kEnableSwitchingMode);
}

@end
