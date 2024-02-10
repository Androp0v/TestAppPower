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
    var uniqueDisplayNames: [String] {
        var set = Set<String>()
        for measurement in cpuPowerHistory {
            for threadPower in measurement.threadsPower {
                set.insert(threadPower.displayName)
            }
        }
        return set.sorted()
    }
    
    static let empty = PowerWidgetInfo(
        cpuPower: .zero,
        cpuEnergy: .zero,
        cpuMaxPower: .zero,
        cpuPowerHistory: [SampleThreadsResult]()
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
            
            Task(priority: .high) { @MainActor in
                self.powerWidgetInfo = PowerWidgetInfo(
                    cpuPower: cpuPower,
                    cpuEnergy: cpuEnergy,
                    cpuMaxPower: cpuMaxPower,
                    cpuPowerHistory: cpuPowerHistory
                )
            }
        }
        return powerWidgetInfo
    }
}
