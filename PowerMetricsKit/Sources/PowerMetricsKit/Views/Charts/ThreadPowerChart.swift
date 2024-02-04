//
//  ThreadPowerChart.swift
//
//
//  Created by Raúl Montón Pinillos on 4/2/24.
//

import Charts
import SwiftUI

struct ThreadPowerChart: View {
    
    let info: PowerWidgetInfo
    let latestSampleTime: Date
    
    var body: some View {
        Chart(info.cpuPowerHistory) { measurement in
            
            ForEach(measurement.threadsPower, id: \.threadID) { threadPower in
                AreaMark(
                    x: .value("Time", measurement.time),
                    y: .value("Power", threadPower.power.total)
                )
                .foregroundStyle(
                    by: .value("Thread ID", "\(threadPower.threadID)")
                )
            }
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
    }
}
