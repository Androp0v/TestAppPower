//
//  ThreadPowerChart.swift
//
//
//  Created by Raúl Montón Pinillos on 4/2/24.
//

import Charts
import SwiftUI

@MainActor struct ThreadPowerChart: View {
    
    let info: PowerWidgetInfo
    let latestSampleTime: Date
    
    @State var model = ThreadPowerChartModel()
    @Environment(\.self) var environment
        
    var body: some View {
        Chart(info.cpuPowerHistory) { measurement in
            
            ForEach(measurement.threadsPower, id: \.threadID) { threadPower in
                AreaMark(
                    x: .value("Time", measurement.time),
                    y: .value("Power", threadPower.power.total)
                )
                .foregroundStyle(
                    by: .value("Thread name", "\(threadPower.displayName)")
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
        .chartForegroundStyleScale(mapping: { (displayName: String) in
            return model.colorForDisplayName(displayName, environment: environment)
        })
        .chartLegend(.hidden)
        .drawingGroup()
        
        ScrollView {
            VStack(alignment: .leading) {
                ForEach(info.uniqueDisplayNames, id: \.self) { displayName in
                    HStack {
                        Circle()
                            .frame(width: 8, height: 8)
                            .foregroundStyle(model.colorForDisplayName(displayName, environment: environment))
                        Text(displayName)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .foregroundStyle(model.colorForDisplayName(displayName, environment: environment))
                    }
                }
            }
        }
    }
}
