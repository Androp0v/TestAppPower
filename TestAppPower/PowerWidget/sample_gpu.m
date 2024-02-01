//
//  sample_gpu.m
//  TestAppPower
//
//  Created by Raúl Montón Pinillos on 27/1/24.
//

#import <Foundation/Foundation.h>
#include <mach/mach_time.h>
// #include "hidsystem/IOHIDEventSystemClient.h"
#include <unistd.h>
#include "sample_gpu.h"

/* Macros for hub userclient methods
 */
#define kIOReportUserClientOpen                 0
#define kIOReportUserClientConfigureInterests   2
#define kIOReportUserClientUpdateKernelBuffer   3

/* Missing constants for dictionary stuff */
#define kDriverIdKey CFSTR("DriverID")
#define kDrivernameKey CFSTR("DriverName")
#define kRawElementskey CFSTR("RawElements")
#define kStatenamesKey CFSTR("StateNames")

#define kIOReportRawElementChunkSize 64

enum {
    kIOReportIterOk,
};

// typedef struct IOReportSubscriptionRef* IOReportSubscriptionRef;
typedef CFDictionaryRef IOReportSampleRef;

extern IOReportSubscriptionRef IOReportCreateSubscription(void* a, CFMutableDictionaryRef desiredChannels, CFMutableDictionaryRef* subbedChannels, uint64_t channel_id, CFTypeRef b);

extern CFMutableDictionaryRef IOReportCopyChannelsInGroup(NSString*, NSString*, uint64_t, uint64_t, uint64_t);
extern CFMutableDictionaryRef IOReportCopyAllChannels(uint64_t, uint64_t);
extern CFMutableDictionaryRef IOReportCopyFilteredChannels(uint64_t, uint64_t, uint64_t);
extern CFMutableDictionaryRef IOReportCreateAggregate(uint64_t);
extern CFMutableDictionaryRef _getChannelAtIndex(uint64_t);

// extern int IOReportGetChannelCount(CFMutableDictionaryRef);
struct IOReporter_client_subscription;

extern CFDictionaryRef IOReportCreateSamples(IOReportSubscriptionRef iorsub, CFMutableDictionaryRef subbedChannels, CFTypeRef a);

typedef int (^ioreportiterateblock)(IOReportSampleRef ch);

extern void IOReportIterate(CFDictionaryRef samples, ioreportiterateblock);
extern int IOReportChannelGetFormat(CFDictionaryRef samples);
extern long IOReportSimpleGetIntegerValue(CFDictionaryRef, int);
extern NSString* IOReportChannelGetDriverName(CFDictionaryRef);
extern NSString* IOReportChannelGetChannelName(CFDictionaryRef);
// extern int IOReportStateGetCount(CFDictionaryRef);
extern uint64_t IOReportStateGetResidency(CFDictionaryRef, int);
extern NSString* IOReportStateGetNameForIndex(CFDictionaryRef, int);
extern uint64_t* IOReportChannelGetChannelID(CFDictionaryRef);
extern NSString* IOReportChannelGetUnitLabel(CFDictionaryRef);
extern NSString* IOReportChannelGetGroup(CFDictionaryRef);
extern NSString* IOReportChannelGetSubGroup(CFDictionaryRef);
extern NSString* IOReportChannelGetLegend(CFDictionaryRef);
extern NSString* IOReportSampleCopyDescription(CFDictionaryRef, int, int);
extern uint64_t IOReportArrayGetValueAtIndex(CFDictionaryRef, int);

extern int IOReportHistogramGetBucketCount(CFDictionaryRef);
extern int IOReportHistogramGetBucketMinValue(CFDictionaryRef, int);
extern int IOReportHistogramGetBucketMaxValue(CFDictionaryRef, int);
extern int IOReportHistogramGetBucketSum(CFDictionaryRef, int);
extern int IOReportHistogramGetBucketHits(CFDictionaryRef, int);

// Convert mach_time (monotonous clock ticks) to seconds.
static double convert_mach_time(uint64_t mach_time) {
    static mach_timebase_info_data_t base = { .numer = 0 };
    if (base.numer == 0) {
        mach_timebase_info(&base);
    }
    double elapsed = (mach_time * base.numer) / base.denom;
    return elapsed / 1e9;
}

#if TARGET_OS_IPHONE
typedef mach_port_t io_object_t;
typedef io_object_t io_iterator_t;
typedef io_object_t io_registry_entry_t;
typedef char io_name_t[128];
typedef UInt32 IOOptionBits;
kern_return_t IORegistryCreateIterator(mach_port_t mainPort, const io_name_t plane, IOOptionBits options, io_iterator_t *iterator);
io_object_t IOIteratorNext(io_iterator_t iterator);

#define kIOServicePlane "IOService"
const mach_port_t kIOMainPortDefault;

// options for IORegistryCreateIterator(), IORegistryEntryCreateIterator, IORegistryEntrySearchCFProperty()
enum {
    kIORegistryIterateRecursively    = 0x00000001,
    kIORegistryIterateParents        = 0x00000002
};
#define kIOReturnSuccess         KERN_SUCCESS
#define IO_OBJECT_NULL  ((io_object_t) 0)

CFTypeRef IORegistryEntryCreateCFProperty(io_registry_entry_t entry, CFStringRef key, CFAllocatorRef allocator, IOOptionBits options );
kern_return_t
IORegistryEntryGetName(
    io_registry_entry_t    entry,
    io_name_t             name );

kern_return_t
IORegistryEntryGetRegistryEntryID(
    io_registry_entry_t    entry,
    uint64_t *        entryID );

kern_return_t
IOObjectRelease(
    io_object_t    object );

#endif

CFMutableDictionaryRef _copy_chann(NSString* group) {
    CFMutableDictionaryRef dict = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, NULL, NULL);
    CFMutableArrayRef channels = CFArrayCreateMutable(kCFAllocatorDefault, 0, NULL);
    
    io_iterator_t iter;
    kern_return_t kr;
    io_registry_entry_t entry;

    kr = IORegistryCreateIterator(kIOMainPortDefault, kIOServicePlane, kIORegistryIterateRecursively, &iter);
    if (kr != kIOReturnSuccess) return NULL;
    
    while ((entry = IOIteratorNext(iter)) != IO_OBJECT_NULL) {
        char name[56];
        uint64_t entid;

        IORegistryCreateCFPropertyL
        CFArrayRef legend = (CFArrayRef)IORegistryEntryCreateCFProperty(entry, CFSTR(kIOReportLegendKey), kCFAllocatorDefault, 0);
        if (legend == NULL) continue;
        
        for (int i = 0; i < CFArrayGetCount(legend); i++) {
            CFDictionaryRef key = CFArrayGetValueAtIndex(legend, i);
            
            if (CFDictionaryContainsValue(key, (CFStringRef) group ) || group == NULL) {
                CFArrayRef chann_array = CFDictionaryGetValue(key, CFSTR(kIOReportLegendChannelsKey));
                
                IORegistryEntryGetName(entry, name);
                IORegistryEntryGetRegistryEntryID(entry, &entid);
                NSString* dname = [[NSString alloc] initWithFormat:@"%s <id: 0x%.2llx>", name, entid];
                
                for (int ii = 0; ii < CFArrayGetCount(chann_array); ii++) {
                    CFMutableDictionaryRef subbdict = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, NULL, NULL);
                    
                    CFDictionaryAddValue(subbdict, kDriverIdKey, CFNumberCreate(kCFAllocatorDefault, kCFNumberLongLongType, &entid));
                    
                    // TODO: uncomment this. for some reason it's value is mutated after the loops are done and turns it into an array???
                    CFDictionaryAddValue(subbdict, kDrivernameKey, (CFStringRef) dname);
                    
                    CFDictionaryAddValue(subbdict, CFSTR(kIOReportLegendInfoKey), CFDictionaryGetValue(key, CFSTR(kIOReportLegendInfoKey)));
                    CFDictionaryAddValue(subbdict, CFSTR(kIOReportLegendGroupNameKey), CFDictionaryGetValue(key, CFSTR(kIOReportLegendGroupNameKey)));
                    CFDictionaryAddValue(subbdict, CFSTR(kIOReportLegendSubGroupNameKey), CFDictionaryGetValue(key, CFSTR(kIOReportLegendSubGroupNameKey)));
                    CFDictionaryAddValue(subbdict, CFSTR(kIOReportLegendChannelsKey), CFArrayGetValueAtIndex(chann_array, ii));
                    
                    CFArrayAppendValue(channels, subbdict);
                }
            }
        }
    }
    
    IOObjectRelease(iter);
    
    if (CFArrayGetCount(channels) != 0)
        CFDictionarySetValue(dict, CFSTR(kIOReportLegendChannelsKey), channels);
    
    CFDictionarySetValue(dict, CFSTR("QueryOpts"), CFSTR("0"));
    
    return dict;
}

double sample_gpu(void) {
    CFMutableDictionaryRef channels;
    channels = IOReportCopyChannelsInGroup(@"Energy Model", 0x0, 0x0, 0x0, 0x0);

    CFMutableDictionaryRef subscribed_channels = NULL;
    IOReportSubscriptionRef sub = IOReportCreateSubscription(NULL, channels, &subscribed_channels, 0, 0);
    
    __block long energy_nJ = NAN;
    CFDictionaryRef samples = NULL;
    if ((samples = IOReportCreateSamples(sub, subscribed_channels, NULL))) {
        IOReportIterate(samples, ^(IOReportSampleRef ch) {
            if ([[(__bridge NSDictionary *)ch objectForKey:@"LegendChannel"] containsObject:@"GPU Energy"]) {
                energy_nJ = IOReportSimpleGetIntegerValue(ch, 0);
                return kIOReportIterOk;
            } else {
                return kIOReportIterOk;
            }
        });
    } else {
        // TODO: Failed to get power state information
    }
    
    double energy_J = (double)energy_nJ / 1e9;
    return energy_J;
}
