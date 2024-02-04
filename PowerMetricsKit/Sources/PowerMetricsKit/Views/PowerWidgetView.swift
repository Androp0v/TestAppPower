//
//  PowerWidgetView.swift
//  TestAppPower
//
//  Created by Raúl Montón Pinillos on 14/1/24.
//

import Charts
import SwiftUI

/// A `View` displaying the power consumption of the app.
@MainActor public struct PowerWidgetView: View {
    
    let pid = ProcessInfo.processInfo.processIdentifier
    let sampleManager = SampleThreadsManager.shared
    let viewModel = PowerWidgetViewModel()
    
    @State var isResettingEnergy: Bool = false
        
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
    
    // MARK: - View body
    
    public var body: some View {
        VStack {
            Text("PID: \(pidFormatter.string(from: NSNumber(value: pid)) ?? "??")")
                .font(.largeTitle)
                .padding(.bottom)
            TimelineView(.periodic(from: .now, by: SampleThreadsManager.samplingTime)) { _ in
                
                let info = viewModel.getLatest(sampleManager: sampleManager)
                let latestSampleTime = info.cpuPowerHistory.last?.time ?? Date.now
                
                Text("CPU power: \(formatPower(power: info.cpuPower))")
                    .monospaced()
                HStack(spacing: 4) {
                    Text("Total energy used: \(formatEnergy(energy: info.cpuEnergy))")
                        .monospaced()
                    resetEnergyButton
                }
                Chart(info.cpuPowerHistory) { measurement in
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
                .chartYAxisLabel(info.cpuMaxPower < 0.1 ? "Power (mW)" : "Power (W)")
                .chartXAxis(.hidden)
                .chartYAxis {
                    if info.cpuMaxPower < 0.1 {
                        AxisMarks(format: ChartPowerFormatStyle.Miliwatts())
                    } else {
                        AxisMarks(format: ChartPowerFormatStyle.Watts())
                    }
                }
                .chartXScale(domain: [
                    latestSampleTime - SampleThreadsManager.samplingTime * Double(SampleThreadsManager.numberOfStoredSamples),
                    latestSampleTime
                ])
                .drawingGroup()
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 24)
                .foregroundStyle(.regularMaterial)
        }
        .task {
            await sampleManager.startSampling(pid: pid)
        }
    }
    
    // MARK: - Subviews
    
    @ViewBuilder var resetEnergyButton: some View {
        Button(
            action: {
                withAnimation {
                    isResettingEnergy = true
                }
                Task { @MainActor in
                    await sampleManager.resetEnergyUsed()
                    withAnimation {
                        isResettingEnergy = false
                    }
                }
            },
            label: {
                Image(systemName: "arrow.uturn.left.circle")
            }
        )
        .foregroundStyle(.secondary)
        #if os(macOS)
        .buttonStyle(.plain)
        #endif
        .disabled(isResettingEnergy)
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
