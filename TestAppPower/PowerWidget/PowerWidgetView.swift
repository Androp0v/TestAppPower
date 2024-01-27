//
//  PowerWidgetView.swift
//  TestAppPower
//
//  Created by Raúl Montón Pinillos on 14/1/24.
//

import Charts
import SwiftUI

/// A `View` displaying the power consumption of the app.
struct PowerWidgetView: View {
    
    let pid = ProcessInfo.processInfo.processIdentifier
    let sampleManager = SampleThreadsManager.shared
    let gpuManager = SampleGPUManager.shared
    
    var pidFormatter: NumberFormatter = {
        let numberFormatter = NumberFormatter()
        numberFormatter.usesGroupingSeparator = false
        return numberFormatter
    }()
    
    var powerFormatter: NumberFormatter = {
        let numberFormatter = NumberFormatter()
        numberFormatter.maximumFractionDigits = 2
        numberFormatter.minimumFractionDigits = 2
        return numberFormatter
    }()
    
    var body: some View {
        VStack {
            Text("PID: \(pidFormatter.string(from: NSNumber(value: pid)) ?? "??")")
                .font(.largeTitle)
                .padding(.bottom)
            TimelineView(.periodic(from: .now, by: sampleManager.samplingTime)) { _ in
                Text("CPU power: \(formatPower(power: sampleManager.sampleThreads(pid).combinedPower.total))")
                    .monospaced()
                Text("Total energy used: \(formatEnergy(energy: sampleManager.totalEnergyUsage))")
                    .monospaced()
                Text("GPU power: \(formatPower(power: gpuManager.sampleGPUPower()))")
                    .monospaced()
                Chart(sampleManager.historicPower.suffix(60)) { measurement in
                    AreaMark(
                        x: .value("Time", measurement.time),
                        y: .value("Power (W)", measurement.combinedPower.efficiency)
                    )
                    .foregroundStyle(
                        by: .value("Name", "Efficiency")
                    )
                    
                    AreaMark(
                        x: .value("Time", measurement.time),
                        y: .value("Power (W)", measurement.combinedPower.performance)
                    )
                    .foregroundStyle(
                        by: .value("Name", "Performance")
                    )
                }
                .chartXAxisLabel("Time")
                .chartYAxisLabel("Power (W)")
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 24)
                .foregroundStyle(.regularMaterial)
        }
    }
    
    func formatPower(power: Double?) -> String {
        guard let power else {
            return "Unavailable"
        }
        if power < 0.1 {
            let power = NSNumber(value: power * 1000)
            return (powerFormatter.string(from: power) ?? "?") + " mW"
        } else {
            let power = NSNumber(value: power)
            return (powerFormatter.string(from: power) ?? "?") + " W"
        }
    }
    
    func formatEnergy(energy: Double) -> String {
        if energy < 0.1 {
            let energy = NSNumber(value: energy * 1000)
            return (powerFormatter.string(from: energy) ?? "?") + " mWh"
        } else {
            let energy = NSNumber(value: energy)
            return (powerFormatter.string(from: energy) ?? "?") + " Wh"
        }
    }
}

#Preview {
    PowerWidgetView()
}
