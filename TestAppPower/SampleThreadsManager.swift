//
//  SampleThreadsManager.swift
//  TestAppPower
//
//  Created by Raúl Montón Pinillos on 20/1/24.
//

import Foundation

struct SampleThreadsResult: Identifiable {
    let id = UUID()
    let time: Date
    let combinedPower: Double
}

class SampleThreadsManager {
    
    var currentThreadCount: Int = 1
    var previousCounters = [UInt64: thread_counters_t]()
    
    var historicPower = [SampleThreadsResult]()
    
    private init(){}
    static let shared = SampleThreadsManager()
    
    func sampleThreads(_ pid: Int32) -> SampleThreadsResult {
        let result = sample_threads(pid)
        self.currentThreadCount = Int(result.thread_count)
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
        free(result.cpu_counters)
        let sampleResult = SampleThreadsResult(
            time: .now,
            combinedPower: combinedPower
        )
        historicPower.append(sampleResult)
        return sampleResult
    }
    
    private func computePower(previous: cpu_counters_t, current: cpu_counters_t) -> Double {
        let elapsedTime = current.time - previous.time
        let energyChange = current.energy - previous.energy
        if !energyChange.isZero {
            return energyChange / elapsedTime
        } else {
            return .zero
        }
    }
}
