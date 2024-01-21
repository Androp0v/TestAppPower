//
//  SampleThreadsManager.swift
//  TestAppPower
//
//  Created by Raúl Montón Pinillos on 20/1/24.
//

import Foundation

enum CoreType {
    case performance
    case efficiency
}

struct CombinedPower {
    let performance: Double
    let efficiency: Double
    
    var total: Double {
        return performance + efficiency
    }
}

struct SampleThreadsResult: Identifiable {
    let id = UUID()
    let time: Date
    let combinedPower: CombinedPower
}

/// The main class interfacing with the C code that retrieves the energy data.
class SampleThreadsManager {
    
    let samplingTime: TimeInterval = 0.5
    
    var currentThreadCount: Int = 1
    var previousCounters = [UInt64: thread_counters_t]()
    
    var historicPower = [SampleThreadsResult]()
    
    private init(){}
    static let shared = SampleThreadsManager()
    
    /// Given the pid for a process, sample all the threads belonging to that process and
    /// return the `CombinedPower` used for that process.
    /// - Parameter pid: The pid of the process to inspect.
    /// - Returns: The `CombinedPower` used by that process.
    func sampleThreads(_ pid: Int32) -> SampleThreadsResult {
        
        // Invoke the C code in sample_threads.c that uses proc_pidinfo to retrieve
        // performance counters including energy usage.
        let result = sample_threads(pid)
        // This points directly to the C array.
        let counters = UnsafeBufferPointer(start: result.cpu_counters, count: Int(result.thread_count))
        // This creates a Swift copy of the C array.
        let countersArray = [thread_counters_t](counters)
        // Free the memory allocated with malloc in sample_threads.c, as we've created
        // a copy for Swift code.
        free(result.cpu_counters)
        
        self.currentThreadCount = Int(result.thread_count)
        
        var combinedPPower = 0.0
        var combinedEPower = 0.0
        for counter in countersArray {
            if let previousCounter = previousCounters[counter.thread_id] {
                let performancePower = computePower(
                    previous: previousCounter,
                    current: counter,
                    type: .performance
                )
                let efficiencyPower = computePower(
                    previous: previousCounter,
                    current: counter,
                    type: .efficiency
                )
                combinedPPower += performancePower
                combinedEPower += efficiencyPower
            }
            previousCounters[counter.thread_id] = counter
        }
        
        let sampleResult = SampleThreadsResult(
            time: .now,
            combinedPower: CombinedPower(
                performance: combinedPPower,
                efficiency: combinedEPower
            )
        )
        historicPower.append(sampleResult)
        return sampleResult
    }
    
    private func computePower(previous: thread_counters_t, current: thread_counters_t, type: CoreType) -> Double {
        let energyChange: Double
        switch type {
        case .performance:
            energyChange = current.performance.energy - previous.performance.energy
        case .efficiency:
            energyChange = current.efficiency.energy - previous.efficiency.energy
        }
        if !energyChange.isZero {
            // The *power* used during a time interval is the *total* energy consumed
            // divided by the time between measurements. Using the counters' ptcd times
            // instead would NOT yield the correct result, as that excludes times where
            // the threads were not running.
            return energyChange / samplingTime
        } else {
            return .zero
        }
    }
}
