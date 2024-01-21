//
//  SimulationView.swift
//  TestAppPower
//
//  Created by Raúl Montón Pinillos on 21/1/24.
//

import Charts
import SwiftUI

struct SimulationView: View {
    
    let simulationManager = SimulationManager(sigma: 10, r: 28, b: 8.0/3.0, particleCount: 10)
    @State var isRunning: Bool = false
    
    var body: some View {
        GeometryReader { geometry in
            TimelineView(.periodic(from: .now, by: 1/60)) { _ in
                Path { path in
                    let size = min(geometry.size.width, geometry.size.height)
                    let scaleFactor = (size / 2) / 25
                    
                    path.move(to: CGPoint(
                        x: (simulationManager.plottablePositions.first?.x ?? .zero) * scaleFactor + size / 2,
                        y: (simulationManager.plottablePositions.first?.z ?? .zero) * scaleFactor
                    ))
                    for position in simulationManager.plottablePositions {
                        path.addLine(to: CGPoint(
                            x: position.x * scaleFactor + size / 2,
                            y: position.z * scaleFactor
                        ))
                    }
                }
                .stroke(.blue, lineWidth: 1)
            }
        }
        .aspectRatio(1.0, contentMode: .fit)
        
        HStack(spacing: 12) {
            if isRunning {
                ProgressView()
                    #if targetEnvironment(macCatalyst)
                    .scaleEffect(0.2)
                    #endif
            }
            Button(
                action: {
                    withAnimation {
                        isRunning = true
                    }
                    Task.detached(priority: .userInitiated) {
                        await simulationManager.simulate()
                        Task { @MainActor in
                            withAnimation {
                                isRunning = false
                            }
                        }
                    }
                },
                label: {
                    HStack {
                        Image(systemName: "gauge.with.dots.needle.100percent")
                            .imageScale(.large)
                        Text("Start simulation")
                    }
                }
            )
            .disabled(isRunning)
            .buttonStyle(.borderedProminent)
        }
    }
}

#Preview {
    SimulationView()
}
