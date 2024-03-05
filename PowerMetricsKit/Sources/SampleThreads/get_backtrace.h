//
//  get_backtrace.h
//  
//
//  Created by Raúl Montón Pinillos on 4/3/24.
//

#ifndef get_backtrace_h
#define get_backtrace_h

#include <stdio.h>
#include <stdint.h>
#include <stdbool.h>
#include <mach/mach_types.h>

void get_backtrace(thread_t thread);

#endif /* get_backtrace_h */
