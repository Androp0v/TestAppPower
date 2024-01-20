//
//  PowerWidgetView.swift
//  TestAppPower
//
//  Created by Raúl Montón Pinillos on 14/1/24.
//

import Charts
import SwiftUI

struct PowerWidgetView: View {
    
    let pid = ProcessInfo.processInfo.processIdentifier
    let sampleManager = SampleThreadsManager.shared
    
    var powerFormatter: NumberFormatter = {
        let numberFormatter = NumberFormatter()
        numberFormatter.maximumFractionDigits = 2
        numberFormatter.minimumFractionDigits = 2
        return numberFormatter
    }()
    
    var body: some View {
        VStack {
            Text("PID: \(pid)")
                .font(.largeTitle)
                .padding(.bottom, 12)
            TimelineView(.periodic(from: .now, by: 0.5)) { _ in
                Text("CPU power: \(powerFormatter.string(from: NSNumber(value: sampleManager.sampleThreads(pid).combinedPower)) ?? "?") W")
                    .monospaced()
                Chart(sampleManager.historicPower) { measurement in
                    AreaMark(
                        x: .value("Time", measurement.time),
                        y: .value("Power (W)", measurement.combinedPower)
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
}

#Preview {
    PowerWidgetView()
}
