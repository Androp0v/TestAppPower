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

class SampleThreadsManager {
    
    let samplingTime: TimeInterval = 0.5
    
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
        free(result.cpu_counters)
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
        let elapsedPTime = current.performance.time - previous.performance.time
        let elapsedETime = current.efficiency.time - previous.efficiency.time
        
        let energyChange: Double
        switch type {
        case .performance:
            energyChange = current.performance.energy - previous.performance.energy
        case .efficiency:
            energyChange = current.efficiency.energy - previous.efficiency.energy
        }
        if !energyChange.isZero {
            return energyChange / samplingTime // (elapsedPTime + elapsedETime)
        } else {
            return .zero
        }
    }
}
