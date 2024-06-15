//
//  SimulationManager.swift
//  TestAppPower
//
//  Created by Raúl Montón Pinillos on 21/1/24.
//

import Foundation
import simd

/// Quick simulation put together to be computationally intensive enough to significantly increase the CPU
/// power consumption (being pretty is a nice bonus).
///
/// Based on Lorenz attractors, best described in Strogatz's _Nonlinear Dynamics and Chaos_, Part 3.
actor SimulationManager {
    
    let sigma: Double
    let r: Double
    let b: Double
    let particleCount: Int
    
    var runningTaskGroup: TaskGroup<Void>?
    
    @MainActor var lastSavedIteration: Int = 0
    @MainActor var plottablePositions: Array<simd_double3>.SubSequence {
        if lastSavedIteration < 1_000 {
            return savedPositions.prefix(lastSavedIteration)
        } else {
            return savedPositions[(lastSavedIteration - 1_000)..<lastSavedIteration]
        }
    }
    @MainActor private var savedPositions: [simd_double3] = [simd_double3](repeating: .zero, count: 100_000)
    private var initialPositions: [simd_double3]
    
    init(sigma: Double, r: Double, b: Double, particleCount: Int) {
        self.sigma = sigma
        self.r = r
        self.b = b
        self.particleCount = particleCount
        self.initialPositions = [simd_double3](repeating: .zero, count: particleCount)
        
        // Initial particle positions
        let originalPosition = simd_double3(x: -9.1, y: -9.02, z: 22.13)
        for index in 0..<particleCount {
            initialPositions[index] = originalPosition + simd_double3.random(in: 0..<0.1)
        }
    }
    
    @MainActor private func resetSavedPositions() {
        self.lastSavedIteration = 0
        self.savedPositions = [simd_double3](repeating: .zero, count: 100_000)
    }
    
    @MainActor private func addSavedPosition(_ newPosition: simd_double3) {
        self.savedPositions[self.lastSavedIteration] = newPosition
        self.lastSavedIteration += 1
    }
    
    /// Start the simulation.
    func simulate() async {
        
        await resetSavedPositions()
        let particleCount = self.particleCount
        let savedPositionsCount = await self.savedPositions.count
        
        #if DEBUG
        let stepsPerSavedPosition: Int = 1_000
        #else
        // Release builds are too fast otherwise (I bet the code is being auto-vectorized
        // by the compiler).
        let stepsPerSavedPosition: Int = 100_000
        #endif
        await withTaskGroup(of: Void.self) { group in
            runningTaskGroup = group
            for particleIndex in 0..<particleCount {
                let initialPosition = self.initialPositions[particleIndex]
                group.addTask(priority: .medium) {
                    var nextPosition = initialPosition
                    for iteration in 0..<(savedPositionsCount * stepsPerSavedPosition) {
                        if Task.isCancelled {
                            return
                        }
                        nextPosition = self.rungeKuttaStep(
                            nextPosition,
                            stepSize: 0.01 / Double(stepsPerSavedPosition)
                        )
                        if particleIndex == 0, iteration % stepsPerSavedPosition == 0 {
                            if Task.isCancelled {
                                return
                            }
                            await self.addSavedPosition(nextPosition)
                        }
                        
                        if iteration % 1_000 == 0 {
                            // Avoid this TaskGroup exhausting Swift Concurrency's thread pool with
                            // long running synchronous tasks by adding a yield() so other tasks have
                            // the opportunity to execute as well.
                            await Task.yield()
                        }
                    }
                    await print("Final position for particle \(particleIndex): \(self.initialPositions[particleIndex])")
                }
            }
            
            await group.waitForAll()
            runningTaskGroup = nil
        }
    }
    
    func stopSimulation() {
        runningTaskGroup?.cancelAll()
        runningTaskGroup = nil
    }
    
    /// A simplistic ODE solver.
    nonisolated func eulerStep(_ position: simd_double3, stepSize: Double) -> simd_double3 {
        var newPosition = position
        newPosition.x += stepSize * xDerivative(position: position)
        newPosition.y += stepSize * yDerivative(position: position)
        newPosition.z += stepSize * zDerivative(position: position)
        return newPosition
    }
    
    /// An acceptable ODE solver.
    nonisolated func rungeKuttaStep(_ position: simd_double3, stepSize: Double) -> simd_double3 {
        let k1 = stepSize * derivative(position: position)
        let k2 = stepSize * derivative(position: position + k1 / 2)
        let k3 = stepSize * derivative(position: position + k2 / 2)
        let k4 = stepSize * derivative(position: position + k3)
        let temp = k1 + 2.0 * k2 + 2.0 * k3 + k4
        return position + temp / 6.0
    }
    
    nonisolated func derivative(position: simd_double3) -> simd_double3 {
        var derivative = position
        derivative.x = xDerivative(position: position)
        derivative.y = yDerivative(position: position)
        derivative.z = zDerivative(position: position)
        return derivative
    }
    
    /// Derivative function of x using Lorentz's equations.
    nonisolated func xDerivative(position: simd_double3) -> Double {
        return sigma * (position.y - position.x)
    }
    /// Derivative function of y using Lorentz's equations.
    nonisolated func yDerivative(position: simd_double3) -> Double {
        return r * position.x - position.y - position.x * position.z
    }
    /// Derivative function of z using Lorentz's equations.
    nonisolated func zDerivative(position: simd_double3) -> Double {
        return position.x * position.y - b * position.z
    }
}
