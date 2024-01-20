//
//  sample_threads.c
//  TestAppPower
//
//  Created by Raúl Montón Pinillos on 14/1/24.
//

#include "sample_threads.h"
#include <stdlib.h>
#include <libproc.h>
#include <mach/mach_init.h>
#include <mach/mach_port.h>
#include <mach/task_info.h>
#include <mach/thread_act.h>
#include <mach/vm_map.h>
#include <mach/task.h>
#include <mach/mach_time.h>
#include <stdio.h>

struct proc_threadcounts_data {
    uint64_t ptcd_instructions;
    uint64_t ptcd_cycles;
    uint64_t ptcd_user_time_mach;
    uint64_t ptcd_system_time_mach;
    uint64_t ptcd_energy_nj;
};

struct proc_threadcounts {
    uint16_t ptc_len;
    uint16_t ptc_reserved0;
    uint32_t ptc_reserved1;
    struct proc_threadcounts_data ptc_counts[20];
};

static double convert_mach_time(uint64_t mach_time) {
    static mach_timebase_info_data_t base = { .numer = 0 };
    if (base.numer == 0) mach_timebase_info(&base);
  
    double elapsed = (mach_time * base.numer) / base.denom;
    return elapsed / 1e9;
}

sample_threads_result sample_threads(int pid) {
 
    mach_port_t me = mach_task_self();
    mach_port_t task;
    kern_return_t res;
    thread_array_t threads;
    mach_msg_type_number_t n_threads;

    res = task_threads(me, &threads, &n_threads);
    if (res != KERN_SUCCESS) {
        // Handle error...
    }
    
    thread_counters_t *counters_array = malloc(sizeof(thread_counters_t) * n_threads);
    
    // double combined_power = 0;
    for (int i = 0; i < n_threads; i++) {
        struct thread_identifier_info th_info;
        mach_msg_type_number_t th_info_count = THREAD_IDENTIFIER_INFO_COUNT;
        thread_t thread = threads[i];
                
        kern_return_t info_result = thread_info(thread, THREAD_IDENTIFIER_INFO, (thread_info_t)&th_info, &th_info_count);
        if (info_result != KERN_SUCCESS) {
            // Handle error...
        }
        
        counters_array[i].thread_id = th_info.thread_id;
        
        struct proc_threadcounts current_counters;
        proc_pidinfo(pid, 34, th_info.thread_id, &current_counters, sizeof(struct proc_threadcounts));
        
        uint64_t p_cycles = current_counters.ptc_counts[0].ptcd_cycles;
        double p_energy = current_counters.ptc_counts[0].ptcd_energy_nj / 1e9;
        double p_time = convert_mach_time(current_counters.ptc_counts[0].ptcd_user_time_mach + current_counters.ptc_counts[0].ptcd_system_time_mach);
        
        uint64_t e_cycles = current_counters.ptc_counts[1].ptcd_cycles;
        double e_energy = current_counters.ptc_counts[1].ptcd_energy_nj / 1e9;
        double e_time = convert_mach_time(current_counters.ptc_counts[1].ptcd_user_time_mach + current_counters.ptc_counts[1].ptcd_system_time_mach);
        
        counters_array[i].performance.cycles = p_cycles;
        counters_array[i].performance.energy = p_energy;
        counters_array[i].performance.time = p_time;
        
        counters_array[i].efficiency.cycles = e_cycles;
        counters_array[i].efficiency.energy = e_energy;
        counters_array[i].efficiency.time = e_time;
    }
    
    sample_threads_result result;
    result.thread_count = n_threads;
    result.cpu_counters = counters_array;
    return result;
}
