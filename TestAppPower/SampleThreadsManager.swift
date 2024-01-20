//
//  SampleThreadsManager.swift
//  TestAppPower
//
//  Created by Raúl Montón Pinillos on 20/1/24.
//

import Foundation

class SampleThreadsManager {
    
    var previousCounters = [uint64: thread_counters_t]()
    
    func sampleThreads(_ pid: Int32) -> String {
        let result = sample_threads(pid)
        let counters = UnsafeBufferPointer(start: result.cpu_counters, count: Int(result.thread_count))
        let countersArray = [thread_counters_t](counters)
        var combinedPower = 0.0
        for counter in countersArray {
            if let previousCounter = previousCounters[counter.thread_id] {
                let performancePower = computePower(
                    previous: previousCounter.performance,
                    current: counter.performance
                )
                let efficiencyPower = computePower(
                    previous: previousCounter.efficiency,
                    current: counter.efficiency
                )
                combinedPower += performancePower + efficiencyPower
            }
            previousCounters[counter.thread_id] = counter
        }
        return "\(combinedPower)"
    }
    
    private func computePower(previous: cpu_counters_t, current: cpu_counters_t) -> Double {
        let elapsedTime = current.time - previous.time
        let energyChange = current.energy - previous.energy
        let power: Double
        if !energyChange.isZero {
            return energyChange / elapsedTime
        } else {
            return .zero
        }
    }
}
