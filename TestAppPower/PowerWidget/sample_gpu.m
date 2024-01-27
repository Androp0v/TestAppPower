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

enum {
    kIOReportIterOk,
};

typedef struct IOReportSubscriptionRef* IOReportSubscriptionRef;
typedef CFDictionaryRef IOReportSampleRef;

extern IOReportSubscriptionRef IOReportCreateSubscription(void* a, CFMutableDictionaryRef desiredChannels, CFMutableDictionaryRef* subbedChannels, uint64_t channel_id, CFTypeRef b);

extern CFMutableDictionaryRef IOReportCopyChannelsInGroup(NSString*, NSString*, uint64_t, uint64_t, uint64_t);
extern CFMutableDictionaryRef IOReportCopyAllChannels(uint64_t, uint64_t);

extern int IOReportGetChannelCount(CFMutableDictionaryRef);
struct IOReporter_client_subscription;

extern CFDictionaryRef IOReportCreateSamples(IOReportSubscriptionRef iorsub, CFMutableDictionaryRef subbedChannels, CFTypeRef a);

typedef int (^ioreportiterateblock)(IOReportSampleRef ch);

extern void IOReportIterate(CFDictionaryRef samples, ioreportiterateblock);
extern int IOReportChannelGetFormat(CFDictionaryRef samples);
extern long IOReportSimpleGetIntegerValue(CFDictionaryRef, int);
extern NSString* IOReportChannelGetDriverName(CFDictionaryRef);
extern NSString* IOReportChannelGetChannelName(CFDictionaryRef);
extern int IOReportStateGetCount(CFDictionaryRef);
extern uint64_t IOReportStateGetResidency(CFDictionaryRef, int);
extern NSString* IOReportStateGetNameForIndex(CFDictionaryRef, int);
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

typedef uint8_t IOReportFormat;
enum {
    kIOReportInvalidFormat = 0,
    kIOReportFormatSimple = 1,
    kIOReportFormatState = 2,
    kIOReportFormatHistogram = 3,
    kIOReportFormatSimpleArray = 4
};

// Convert mach_time (monotonous clock ticks) to seconds.
static double convert_mach_time(uint64_t mach_time) {
    static mach_timebase_info_data_t base = { .numer = 0 };
    if (base.numer == 0) {
        mach_timebase_info(&base);
    }
    double elapsed = (mach_time * base.numer) / base.denom;
    return elapsed / 1e9;
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
