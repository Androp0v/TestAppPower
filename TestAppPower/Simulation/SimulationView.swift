//
//  SimulationView.swift
//  TestAppPower
//
//  Created by Raúl Montón Pinillos on 21/1/24.
//

import Charts
import simd
import SwiftUI

struct SimulationView: View {
    
    let simulationManager = SimulationManager(sigma: 10, r: 28, b: 8.0/3.0, particleCount: 10)
    @State var isRunning: Bool = false
    
    var updateFrequency: PeriodicTimelineSchedule {
        if isRunning {
            return .periodic(from: .now, by: 1/60)
        } else {
            return .periodic(from: .now, by: .infinity)
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let scaleFactor = (size / 2) / 25
            TimelineView(updateFrequency) { _ in
                ZStack(alignment: .topLeading) {
                    
                    ForEach(plottablePathData()) { pathData in
                        Path { path in
                            path.move(to: CGPoint(
                                x: (pathData.positions.first?.x ?? .zero) * scaleFactor + size / 2,
                                y: (pathData.positions.first?.z ?? .zero) * scaleFactor
                            ))
                            for position in pathData.positions {
                                path.addLine(to: CGPoint(
                                    x: position.x * scaleFactor + size / 2,
                                    y: position.z * scaleFactor
                                ))
                            }
                        }
                        .stroke(.blue.opacity(pathData.opacity), lineWidth: 1)
                    }
                    
                    if let lastPosition = simulationManager.plottablePositions.last {
                        Circle()
                            .frame(width: 4, height: 4)
                            .offset(
                                x: lastPosition.x * scaleFactor + size / 2 - 2,
                                y: lastPosition.z * scaleFactor - 2
                            )
                            .foregroundStyle(.blue)
                    }
                }
            }
        }
        .aspectRatio(1.0, contentMode: .fit)
        
        HStack(spacing: 4) {
            if isRunning {
                ProgressView()
                    #if os(macOS)
                    .scaleEffect(0.5)
                    #endif
            }
            Button(
                action: {
                    if !isRunning {
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
                    } else {
                        Task {
                            await simulationManager.stopSimulation()
                        }
                        withAnimation {
                            isRunning = false
                        }
                    }
                },
                label: {
                    if !isRunning {
                        HStack {
                            Image(systemName: "gauge.with.dots.needle.100percent")
                                .imageScale(.large)
                            Text("Start simulation")
                        }
                    } else {
                        HStack {
                            Image(systemName: "stop.circle")
                                .imageScale(.large)
                            Text("Stop simulation")
                        }
                    }
                }
            )
            .buttonStyle(.borderedProminent)
        }
    }
    
    struct PathData: Identifiable {
        let id = UUID()
        let positions: Array<simd_double3>.SubSequence
        let opacity: Double
    }
    
    func plottablePathData() -> [PathData] {
        var pathData = [PathData]()
        var remainingPositions = simulationManager.plottablePositions
        var opacity = 1.0
        while !remainingPositions.isEmpty {
            let current = remainingPositions.suffix(10)
            pathData.append(PathData(positions: current, opacity: opacity))
            
            remainingPositions = remainingPositions.dropLast(9)
            opacity -= 0.01
        }
        return pathData
    }
}

#Preview {
    SimulationView()
}
