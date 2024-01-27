//
//  sample_gpu.h
//  TestAppPower
//
//  Created by Raúl Montón Pinillos on 27/1/24.
//

#ifndef sample_gpu_h
#define sample_gpu_h

typedef struct {
    double time;
    double energy_J;
} sample_gpu_result;

double sample_gpu(void);

#endif /* sample_gpu_h */
