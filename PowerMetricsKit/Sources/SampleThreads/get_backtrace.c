//
//  get_backtrace.c
//  
//
//  Created by Raúl Montón Pinillos on 4/3/24.
//

#include "get_backtrace.h"
#include <stdlib.h>
#include <stdio.h>
#include <execinfo.h>
#include <signal.h>
#include <pthread.h>
#include <mach/mach_init.h>
#include <mach/thread_act.h>
#include <mach/vm_map.h>
#include <mach-o/loader.h>
#include <dlfcn.h>
#import <mach-o/dyld.h>

// Bitmask to strip pointer authentication (PAC).
#define PAC_STRIPPING_BITMASK 0x0000000FFFFFFFFF
// Max number of frames in stack trace
#define MAX_FRAME_DEPTH 128

static void backtracer() {
    void *array[10];
    int size;
    size = backtrace(array, 10);
    for (int i = 0; i < size; i++) {
        printf ("%p ", array[i]);
    }
    printf("\n");
}

static intptr_t cached_aslr_slide = 0x0;

intptr_t get_aslr_slide() {
    uint32_t numImages = _dyld_image_count();
    for (uint32_t i = 0; i < numImages; i++) {
        const struct mach_header *header = _dyld_get_image_header(i);
        const char *name = _dyld_get_image_name(i);
        const char *p = strrchr(name, '/');
        if (p && (strcmp(p + 1, "TestAppPower") == 0)) {
            const struct mach_header *header = _dyld_get_image_header(i);
            intptr_t slide = _dyld_get_image_vmaddr_slide(i);
            printf("ASLR Slide: %p \n", (void *)slide);
            cached_aslr_slide = slide;
        }
    }
    return 0;
}

bool apply_offset(mach_vm_address_t base_address, int64_t offset, mach_vm_address_t *result) {
    /* Check for overflow */
    if (offset > 0 && UINT64_MAX - offset < base_address) {
        return false;
    } else if (offset < 0 && (offset * -1) > base_address) {
        return false;
    }
    
    if (result != NULL) {
        *result = base_address + offset;
    }
    
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

void frame_walk(mach_port_t task, arm_thread_state64_t thread_state, vm_address_t aslr_slide) {
    int depth = 0;
    uint64_t frame_pointer_addresses[MAX_FRAME_DEPTH] = { 0 };
    uint64_t caller_addresses[MAX_FRAME_DEPTH] = { 0 };
    
    uint64_t current_frame_pointer;
    uint64_t next_frame_pointer;
    
    Dl_info info;
    if (dladdr(thread_state.__lr, &info) != 0) {
        const char *p = strrchr(info.dli_fname, '/');
        if (p && (strcmp(p + 1, "TestAppPower") == 0)) {
            printf("[TestAppPower]\n");
            
            // Let's walk the stack only for TestAppPower frames...
            while (true) {
                
                if (depth == 0) {
                    uint64_t initial_frame_pointer = (thread_state.__fp & PAC_STRIPPING_BITMASK);
                    current_frame_pointer = (initial_frame_pointer & PAC_STRIPPING_BITMASK);
                }
                
                if (current_frame_pointer == 0x0) {
                    // TODO: Terminated frame
                    break;
                }
                
                kern_return_t result = task_memcpy(task,
                                                   current_frame_pointer,
                                                   0,
                                                   &next_frame_pointer,
                                                   sizeof(int64_t));
                if (result != KERN_SUCCESS) {
                    break;
                }
                next_frame_pointer = (next_frame_pointer & PAC_STRIPPING_BITMASK);
                
                // Get the caller address (Link Register, lr) knowing it's a 8-byte offset from the
                // frame pointer (fp).
                uint64_t caller_address;
                uint64_t caller_address_pointer = (current_frame_pointer & PAC_STRIPPING_BITMASK) + 8;
                kern_return_t caller_retrieval_result = task_memcpy(task,
                                                                    caller_address_pointer,
                                                                    0,
                                                                    &caller_address,
                                                                    sizeof(void *));
                // TODO:
                // Investigate why this doesn't always match the lr register of the thread_state
                // at depth 0, accessed via thread_state.__lr.
                caller_address = caller_address & PAC_STRIPPING_BITMASK;
                
                // Save info for this frame
                frame_pointer_addresses[depth] = current_frame_pointer;
                if (caller_retrieval_result == KERN_SUCCESS) {
                    caller_addresses[depth] = caller_address;
                }
                
                // Update depth and exit if max depth reached
                depth += 1;
                if (depth >= MAX_FRAME_DEPTH) {
                    break;
                }
                current_frame_pointer = next_frame_pointer;
            }
            
            for (int i = 0; i < MAX_FRAME_DEPTH; i++) {
                if (frame_pointer_addresses[i] == 0x0) {
                    break;
                }
                Dl_info info;
                if (dladdr(caller_addresses[i], &info) != 0) {
                    const char *p = strrchr(info.dli_fname, '/');
                    printf("%d %s %p\n",
                           i,
                           p + 1,
                           (void *)(caller_addresses[i] - aslr_slide));
                } else if (caller_addresses[i] == 0x0) {
                    printf("%d Unable to retrieve caller address. \n", i);
                } else {
                    // Address doesn't point into a Mach-O memory section.
                    printf("%d Unable to retrieve Mach-O image from address. \n", i);
                }
            }
            printf("\n");
        } else {
            // printf("%s \n", info.dli_fname);
        }
    }
}

void get_backtrace(thread_t thread) {
    
    thread_t current_thread = mach_thread_self();
    
    if (current_thread == thread) {
        // backtracer();
    } else {
        thread_suspend(thread);
        
        vm_address_t aslr_slide;
        if (cached_aslr_slide != 0) {
            aslr_slide = cached_aslr_slide;
        } else {
            aslr_slide = get_aslr_slide();
        }
        
        mach_msg_type_number_t state_count = ARM_UNIFIED_THREAD_STATE_COUNT;
        arm_thread_state64_t thread_state;
        kern_return_t thread_state_result = thread_get_state(thread,
                                                             ARM_THREAD_STATE64,
                                                             (thread_state_t) &thread_state,
                                                             &state_count);
        frame_walk(mach_task_self(), thread_state, aslr_slide);
        
        thread_resume(thread);
    }
}
