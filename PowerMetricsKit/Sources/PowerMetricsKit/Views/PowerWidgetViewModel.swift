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
    
    static let empty = PowerWidgetInfo(
        cpuPower: .zero,
        cpuEnergy: .zero,
        cpuMaxPower: .zero,
        cpuPowerHistory: [SampleThreadsResult]()
    )
}

/// Class to bridge the `SampleThreadsManager` to the UI.
@Observable class PowerWidgetViewModel {
    
    var info: PowerWidgetInfo = .empty
    var threadColors = [String: Color]()
    
    init() {
        startTimer()
    }
    
    func update() {
        Task(priority: .high) { @SampleThreadsActor in
            let sampleManager = SampleThreadsManager.shared
            let cpuPower = sampleManager.history.samples.last?.allThreadsPower.total ?? .zero
            let cpuEnergy = sampleManager.totalEnergyUsage
            let cpuPowerHistory = sampleManager.history.samples
            let cpuMaxPower = sampleManager.history.maxPower
            
            Task(priority: .high) { @MainActor in
                self.info = PowerWidgetInfo(
                    cpuPower: cpuPower,
                    cpuEnergy: cpuEnergy,
                    cpuMaxPower: cpuMaxPower,
                    cpuPowerHistory: cpuPowerHistory
                )
            }
        }
    }
    
    func startTimer() {
        Timer.scheduledTimer(withTimeInterval: SampleThreadsManager.samplingTime, repeats: true) { timer in
            self.update()
        }
    }
}
