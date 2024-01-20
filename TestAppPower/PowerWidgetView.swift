//
//  PowerWidgetView.swift
//  TestAppPower
//
//  Created by Raúl Montón Pinillos on 14/1/24.
//

import SwiftUI

struct PowerWidgetView: View {
    
    let pid = ProcessInfo.processInfo.processIdentifier
    let sampleManager = SampleThreadsManager()
    
    var body: some View {
        VStack {
            Text("PID: \(pid)")
                .font(.largeTitle)
                .padding(.bottom, 12)
            TimelineView(.periodic(from: .now, by: 0.5)) { _ in
                Text("Power: \(sampleManager.sampleThreads(pid)) W")
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
