//
//  sample_threads.c
//  TestAppPower
//
//  Created by Raúl Montón Pinillos on 14/1/24.
//

#include "sample_threads.h"
#include <dispatch/dispatch.h>
#include <stdlib.h>
#include <mach/mach_init.h>
#include <mach/mach_port.h>
#include <mach/task_info.h>
#include <mach/thread_act.h>
#include <mach/vm_map.h>
#include <mach/task.h>
#include <mach/mach_time.h>
#include <stdio.h>
#include <execinfo.h>

// Bitmask to strip pointer authentication (PAC).
#define PAC_STRIPPING_BITMASK 0x0000000FFFFFFFFF
// Max number of frames in stack trace
#define MAX_FRAME_DEPTH 16

// Technically private structs, from:
// https://github.com/apple-oss-distributions/xnu/blob/aca3beaa3dfbd42498b42c5e5ce20a938e6554e5/bsd/sys/proc_info.h#L153
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

// PROC_PIDTHREADCOUNTS is also private, see:
// https://github.com/apple-oss-distributions/xnu/blob/aca3beaa3dfbd42498b42c5e5ce20a938e6554e5/bsd/sys/proc_info.h#L927
#define PROC_PIDTHREADCOUNTS 34

// On macOS, proc_pidinfo is available as part of the libproc headers. On iOS, those
// headers are not available.
int proc_pidinfo(int pid, int flavor, uint64_t arg, void *buffer, int buffersize);

// Convert mach_time (monotonous clock ticks) to seconds.
static double convert_mach_time(uint64_t mach_time) {
    static mach_timebase_info_data_t base = { .numer = 0 };
    if (base.numer == 0) {
        mach_timebase_info(&base);
    }
    double elapsed = (mach_time * base.numer) / base.denom;
    return elapsed / 1e9;
}

bool apply_offset(mach_vm_address_t base_address, int64_t offset, mach_vm_address_t *result) {
    /* Check for overflow */
    if (offset > 0 && UINT64_MAX - offset < base_address) {
        return false;
    } else if (offset < 0 && (offset * -1) > base_address) {
        return false;
    }
    
    if (result != NULL)
        *result = base_address + offset;
    
    return true;
}

kern_return_t task_memcpy(mach_port_t task, mach_vm_address_t address, int64_t offset, void *dest, mach_vm_size_t length) {
    mach_vm_address_t target;
    kern_return_t kt;

    /* Compute the target address and check for overflow */
    if (!apply_offset(address, offset, &target)) {
        // TODO: Handle error...
    }
    
    vm_size_t read_size = length;
    return vm_read_overwrite(task, target, length, (pointer_t) dest, &read_size);
}

void frame_walk(mach_port_t task, arm_thread_state64_t thread_state) {
    int depth = 0;
    uint64_t stack_trace[MAX_FRAME_DEPTH] = { 0 };
    
    uint64_t initial_frame_pointer = (thread_state.__fp & PAC_STRIPPING_BITMASK);
    uint64_t initial_program_counter = (thread_state.__pc & PAC_STRIPPING_BITMASK);
    
    uint64_t current_frame_pointer;
    uint64_t next_frame_pointer;
    kern_return_t result = task_memcpy(task,
                                       initial_frame_pointer,
                                       0,
                                       &current_frame_pointer,
                                       2 * sizeof(int64_t));
    current_frame_pointer = current_frame_pointer & PAC_STRIPPING_BITMASK;
        
    while (true) {
        if (current_frame_pointer == 0x0) {
            // TODO: Terminated frame
            printf("Final frame\n");
            break;
        }
        
        kern_return_t result = task_memcpy(task,
                                           current_frame_pointer,
                                           0,
                                           &next_frame_pointer,
                                           2 * sizeof(int64_t));
        next_frame_pointer = (next_frame_pointer & PAC_STRIPPING_BITMASK);
        
        if (next_frame_pointer < current_frame_pointer) {
            // Wrong direction, bad frame
            printf("WARNING: Wrong stack direction\n");
            break;
        }
        printf("Moving to previous frame\n");
        current_frame_pointer = next_frame_pointer;
        stack_trace[depth] = current_frame_pointer;
        depth += 1;
        
        if (depth >= MAX_FRAME_DEPTH) {
            printf("Reached max frame depth\n");
            break;
        }
    }
}

sample_threads_result sample_threads(int pid) {
 
    mach_port_t me = mach_task_self();
    kern_return_t res;
    thread_array_t threads;
    mach_msg_type_number_t n_threads;

    // Here we'd expect task_threads to always succeed as the process being inspected
    // is the same process that is making the call. Attempting to inspect tasks for
    // different processes raises KERN_FAILURE unless the caller has root privileges.
    //
    // task_threads(me, &threads, &n_threads) retrieves all the threads for the current
    // process.
    //
    // TODO/Note: I believe that with very few extra steps just before this code (using
    // proc_listpids to get the pids of all running processes on the system and using
    // task_for_pid to get the task from the pid), one could easily build macOS's
    // powermetrics utility.
    // Of course, the same limitations would apply (needing to run as root) as both
    // proc_listpids and task_for_pid return KERN_FAILURE if not running as root.
    res = task_threads(me, &threads, &n_threads);
    if (res != KERN_SUCCESS) {
        // TODO: Handle error...
    }
    
    sampled_thread_info_t *counters_array = malloc(sizeof(sampled_thread_info_t) * n_threads);
    
    // Loop over all the threads of the current process.
    for (int i = 0; i < n_threads; i++) {
        struct thread_identifier_info th_info;
        mach_msg_type_number_t th_info_count = THREAD_IDENTIFIER_INFO_COUNT;
        thread_t thread = threads[i];
        
        // We use thread_info to retrieve the Mach thread id of the thread we want to
        // retrieve power counters from.
        kern_return_t info_result = thread_info(thread,
                                                THREAD_IDENTIFIER_INFO,
                                                (thread_info_t)&th_info,
                                                &th_info_count);
        
        // As before, we expect thread_info to succeed as the thread being inspected
        // has the same parent process.
        if (info_result != KERN_SUCCESS) {
            // TODO: Handle error...
        }
        
        counters_array[i].thread_id = th_info.thread_id;
        
        // Attempt to retrieve the thread name
        struct thread_extended_info th_extended_info;
        mach_msg_type_number_t th_extended_info_count = THREAD_EXTENDED_INFO_COUNT;
        kern_return_t extended_info_result = thread_info(thread,
                                                         THREAD_EXTENDED_INFO,
                                                         (thread_info_t)&th_extended_info,
                                                         &th_extended_info_count);
        if (extended_info_result == KERN_SUCCESS) {
            strcpy(counters_array[i].pthread_name, th_extended_info.pth_name);
        } else {
            strcpy(counters_array[i].pthread_name, "");
        }
        
        // Attempt to retrieve the libdispatch queue
        struct thread_identifier_info th_id_info;
        mach_msg_type_number_t th_id_count = THREAD_IDENTIFIER_INFO_COUNT;
        kern_return_t id_info_result = thread_info(thread,
                                                   THREAD_IDENTIFIER_INFO,
                                                   (thread_info_t)&th_id_info,
                                                   &th_id_count);
        
        dispatch_queue_t * _Nullable thread_queue = th_id_info.dispatch_qaddr;
        if (id_info_result == KERN_SUCCESS && thread_queue != NULL) {
            const char  * _Nullable queue_label = dispatch_queue_get_label(*thread_queue);
            strcpy(counters_array[i].dispatch_queue_name, queue_label);
        } else {
            strcpy(counters_array[i].dispatch_queue_name, "");
        }
        
        // Retrieve power counters info
        
        struct proc_threadcounts current_counters;
        
        // This flavor of proc_pidinfo using PROC_PIDTHREADCOUNTS is technically private, see:
        // https://github.com/apple-oss-distributions/xnu/blob/aca3beaa3dfbd42498b42c5e5ce20a938e6554e5/bsd/sys/proc_info.h#L898
        // Reproduced below in case link is not available in the future:
        //
        // PROC_PIDTHREADCOUNTS returns a list of counters for the given thread,
        // separated out by the "perf-level" it was running on (typically either
        // "performance" or "efficiency").
        //
        // This interface works a bit differently from the other proc_info(3) flavors.
        // It copies out a structure with a variable-length array at the end of it.
        // The start of the `proc_threadcounts` structure contains a header indicating
        // the length of the subsequent array of `proc_threadcounts_data` elements.
        //
        // To use this interface, first read the `hw.nperflevels` sysctl to find out how
        // large to make the allocation that receives the counter data:
        //
        //     sizeof(proc_threadcounts) + nperflevels * sizeof(proc_threadcounts_data)
        //
        // Use the `hw.perflevel[0-9].name` sysctl to find out which perf-level maps to
        // each entry in the array.
        //
        // The complete usage would be (omitting error reporting):
        //
        //     uint32_t len = 0;
        //     int ret = sysctlbyname("hw.nperflevels", &len, &len_sz, NULL, 0);
        //     size_t size = sizeof(struct proc_threadcounts) +
        //             len * sizeof(struct proc_threadcounts_data);
        //     struct proc_threadcounts *counts = malloc(size);
        //     // Fill this in with a thread ID, like from `PROC_PIDLISTTHREADS`.
        //     uint64_t tid = 0;
        //     int size_copied = proc_info(getpid(), PROC_PIDTHREADCOUNTS, tid, counts,
        //             size);
        proc_pidinfo(pid, // pid of the process
                     PROC_PIDTHREADCOUNTS, // The proc_pidinfo "flavor": different flavors have different return structures.
                     th_info.thread_id, // The mach thread id of the thread we're retrieving the counters from.
                     &current_counters, // The address of the result structure.
                     sizeof(struct proc_threadcounts)); // The size of the result structure.
        
        // Thread counters when running on Performance cores
        uint64_t p_cycles = current_counters.ptc_counts[0].ptcd_cycles;
        double p_energy = current_counters.ptc_counts[0].ptcd_energy_nj / 1e9;
        double p_time = convert_mach_time(current_counters.ptc_counts[0].ptcd_user_time_mach + current_counters.ptc_counts[0].ptcd_system_time_mach);
        
        // Thread counters when running on Efficiency cores
        uint64_t e_cycles = current_counters.ptc_counts[1].ptcd_cycles;
        double e_energy = current_counters.ptc_counts[1].ptcd_energy_nj / 1e9;
        double e_time = convert_mach_time(current_counters.ptc_counts[1].ptcd_user_time_mach + current_counters.ptc_counts[1].ptcd_system_time_mach);
        
        counters_array[i].performance.cycles = p_cycles;
        counters_array[i].performance.energy = p_energy;
        counters_array[i].performance.time = p_time;
        
        counters_array[i].efficiency.cycles = e_cycles;
        counters_array[i].efficiency.energy = e_energy;
        counters_array[i].efficiency.time = e_time;
        
        /* Fetch the thread state */
        #if defined(__aarch64__)
        
        void *array[10];
        int size;
        char **strings;
        size = backtrace(array, 10);
        strings = backtrace_symbols(array, size);
        for (i = 0; i < size; i++) {
            printf ("%s\n", strings[i]);
        }
        
        /*
        mach_msg_type_number_t state_count = ARM_UNIFIED_THREAD_STATE_COUNT;
        arm_thread_state64_t thread_state;
        kern_return_t thread_state_result = thread_get_state(thread,
                                                             ARM_THREAD_STATE64,
                                                             (thread_state_t) &thread_state,
                                                             &state_count);
        
        frame_walk(me, thread_state);
        
        if (thread_state_result != KERN_SUCCESS) {
            // TODO: Handle error...
        }
         */
        #endif
    }
    
    sample_threads_result result;
    result.thread_count = n_threads;
    result.cpu_counters = counters_array;
    return result;
}
