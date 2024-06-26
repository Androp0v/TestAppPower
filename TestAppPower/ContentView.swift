//
//  ContentView.swift
//  TestAppPower
//
//  Created by Raúl Montón Pinillos on 14/1/24.
//

import PowerMetricsKit
import SwiftUI

struct ContentView: View {
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State var isRunning: Bool = false
    @State var result: Double?
    
    let config = PowerMetricsConfig(
        samplingTime: 0.5,
        numberOfStoredSamples: 60,
        retrieveDispatchQueueName: true,
        retrieveBacktraces: true
    )
    
    var body: some View {
        let layout = horizontalSizeClass == .compact ? AnyLayout(VStackLayout(spacing: .zero)) : AnyLayout(HStackLayout())
        layout {
            PowerWidgetView(config: config)
                .frame(maxWidth: 500, maxHeight: 800)
                .padding()
                .padding(.leading, horizontalSizeClass != .compact ? 48 : 0)
            VStack {
                SimulationView()
            }
            .padding()
        }
    }
}

#Preview {
    ContentView()
}
