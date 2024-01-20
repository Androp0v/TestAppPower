//
//  sample_threads.h
//  TestAppPower
//
//  Created by Raúl Montón Pinillos on 14/1/24.
//

#ifndef sample_threads_h
#define sample_threads_h

#include <stdint.h>
#include <stdbool.h>

typedef struct {
    /// Cycles executed by the thread.
    uint64_t cycles;
    /// Energy used by thread, J.
    double energy;
    /// Sampling interval in seconds.
    double time;
} cpu_counters_t;

typedef struct {
    /// Thread ID.
    uint64_t thread_id;
    /// Performance core counters.
    cpu_counters_t performance;
    /// Efficiency core counters.
    cpu_counters_t efficiency;
} thread_counters_t;

typedef struct {
    uint64_t thread_count;
    thread_counters_t *cpu_counters;
} sample_threads_result;

sample_threads_result sample_threads(int pid);

#endif /* sample_threads_h */
