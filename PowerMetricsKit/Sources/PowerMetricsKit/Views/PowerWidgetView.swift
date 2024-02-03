//
//  PowerWidgetView.swift
//  TestAppPower
//
//  Created by Raúl Montón Pinillos on 14/1/24.
//

import Charts
import SwiftUI

/// A `View` displaying the power consumption of the app.
public struct PowerWidgetView: View {
    
    let pid = ProcessInfo.processInfo.processIdentifier
    let sampleManager = SampleThreadsManager.shared
    
    @State var cpuPower: Power = .zero
    @State var cpuEnergy: Double = .zero
    @State var cpuMaxPower: Power = .zero
    @State var cpuPowerHistory = [SampleThreadsResult]()
        
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
    
    public init() {}
    
    public var body: some View {
        VStack {
            Text("PID: \(pidFormatter.string(from: NSNumber(value: pid)) ?? "??")")
                .font(.largeTitle)
                .padding(.bottom)
            TimelineView(.periodic(from: .now, by: sampleManager.samplingTime)) { _ in
                Text("CPU power: \(formatPower(power: refreshState(for: pid)))")
                    .monospaced()
                Text("Total energy used: \(formatEnergy(energy: cpuEnergy))")
                    .monospaced()
                Chart(cpuPowerHistory) { measurement in
                    AreaMark(
                        x: .value("Time", measurement.time),
                        y: .value("Power", measurement.combinedPower.efficiency)
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
                .chartYAxisLabel(cpuMaxPower < 0.1 ? "Power (mW)" : "Power (W)")
                .chartXAxis(.hidden)
                .chartYAxis {
                    if cpuMaxPower < 0.1 {
                        AxisMarks(format: ChartPowerFormatStyle.Miliwatts())
                    } else {
                        AxisMarks(format: ChartPowerFormatStyle.Watts())
                    }
                }
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 24)
                .foregroundStyle(.regularMaterial)
        }
    }
    
    func refreshState(for pid: Int32) -> Power {
        Task { @MainActor in
            let cpuPower = await sampleManager.sampleThreads(pid).combinedPower.total
            let cpuEnergy = await sampleManager.totalEnergyUsage
            let cpuPowerHistory = await sampleManager.history.samples
            let cpuMaxPower = await sampleManager.history.maxPower
            
            self.cpuPower = cpuPower
            self.cpuEnergy = cpuEnergy
            self.cpuPowerHistory = cpuPowerHistory
            self.cpuMaxPower = cpuMaxPower
        }
        return self.cpuPower
    }
    
    func formatPower(power: Double) -> String {
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
