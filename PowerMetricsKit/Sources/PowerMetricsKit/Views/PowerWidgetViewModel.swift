//
//  PowerWidgetViewModel.swift
//
//
//  Created by Raúl Montón Pinillos on 4/2/24.
//

import Foundation
import SwiftUI

struct PowerWidgetInfo {
    var cpuPower: Power
    var cpuEnergy: Energy
    var cpuMaxPower: Power
    var cpuPowerHistory: [SampleThreadsResult]
    var latestSampleTime: Date? {
        return cpuPowerHistory.last?.time
    }
    var uniqueThreads: [ThreadSample] {
        var threadSamples = [ThreadSample]()
        var threadIDs = Set<String>()
        for measurement in cpuPowerHistory.reversed() {
            for threadSample in measurement.threadSamples {
                if !threadIDs.contains(threadSample.displayName) {
                    threadIDs.insert(threadSample.displayName)
                    threadSamples.append(threadSample)
                }
            }
        }
        return threadSamples.sorted(by: { $0.displayName < $1.displayName })
    }
    var backtraces: [Backtrace]
    
    static let empty = PowerWidgetInfo(
        cpuPower: .zero,
        cpuEnergy: .zero,
        cpuMaxPower: .zero,
        cpuPowerHistory: [SampleThreadsResult](), 
        backtraces: [Backtrace]()
    )
}

/// Class to bridge the `SampleThreadsManager` to the UI.
@MainActor class PowerWidgetViewModel {
    
    var powerWidgetInfo: PowerWidgetInfo = .empty
    var threadColors = [String: Color]()
    
    init() {}
    
    func getLatest(sampleManager: SampleThreadsManager) -> PowerWidgetInfo {
        Task(priority: .high) { @SampleThreadsActor in
            let cpuPower = sampleManager.history.samples.last?.allThreadsPower.total ?? .zero
            let cpuEnergy = sampleManager.totalEnergyUsage
            let cpuPowerHistory = sampleManager.history.samples
            let cpuMaxPower = sampleManager.history.maxPower
            let backtraces = sampleManager.backtraces
            
            Task(priority: .high) { @MainActor in
                self.powerWidgetInfo = PowerWidgetInfo(
                    cpuPower: cpuPower,
                    cpuEnergy: cpuEnergy,
                    cpuMaxPower: cpuMaxPower,
                    cpuPowerHistory: cpuPowerHistory,
                    backtraces: backtraces
                )
            }
        }
        return powerWidgetInfo
    }
}
