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
class SimulationManager {
    
    var lastSavedIteration: Int = 0
    var plottablePositions: Array<simd_double3>.SubSequence {
        if lastSavedIteration < 1_000 {
            return savedPositions.prefix(lastSavedIteration)
        } else {
            return savedPositions[(lastSavedIteration - 1_000)..<lastSavedIteration]
        }
    }
    private var savedPositions: [simd_double3] = [simd_double3](repeating: .zero, count: 100_000)
    private var particlePositions: [simd_double3]
    
    let sigma: Double
    let r: Double
    let b: Double
    let particleCount: Int
    
    init(sigma: Double, r: Double, b: Double, particleCount: Int) {
        self.sigma = sigma
        self.r = r
        self.b = b
        self.particleCount = particleCount
        self.particlePositions = [simd_double3](repeating: .zero, count: particleCount)
        
        initParticlePositions()
    }
    
    /// Start the simulation.
    func simulate() async {
        let stepsPerSavedPosition: Int = 1000
        await withTaskGroup(of: Void.self) { group in
            for particleIndex in 0..<particleCount {
                let initialPosition = self.particlePositions[particleIndex]
                group.addTask {
                    var nextPosition = initialPosition
                    for iteration in 0..<(self.savedPositions.count * stepsPerSavedPosition) {
                        nextPosition = self.rungeKuttaStep(
                            nextPosition,
                            stepSize: 0.01 / Double(stepsPerSavedPosition)
                        )
                        if particleIndex == 0, iteration % stepsPerSavedPosition == 0 {
                            self.savedPositions[self.lastSavedIteration] = nextPosition
                            self.lastSavedIteration += 1
                        }
                    }
                    print("Final position for particle \(particleIndex): \(self.particlePositions[particleIndex])")
                }
            }
        }
    }
    
    func initParticlePositions() {
        let originalPosition = simd_double3(x: -9.1, y: -9.02, z: 22.13)
        for index in 0..<particleCount {
            particlePositions[index] = originalPosition + simd_double3.random(in: 0..<0.1)
        }
    }
    
    /// A simplistic ODE solver.
    func eulerStep(_ position: simd_double3, stepSize: Double) -> simd_double3 {
        var newPosition = position
        newPosition.x += stepSize * xDerivative(position: position)
        newPosition.y += stepSize * yDerivative(position: position)
        newPosition.z += stepSize * zDerivative(position: position)
        return newPosition
    }
    
    /// An acceptable ODE solver.
    func rungeKuttaStep(_ position: simd_double3, stepSize: Double) -> simd_double3 {
        let k1 = stepSize * derivative(position: position)
        let k2 = stepSize * derivative(position: position + k1 / 2)
        let k3 = stepSize * derivative(position: position + k2 / 2)
        let k4 = stepSize * derivative(position: position + k3)
        let temp = k1 + 2.0 * k2 + 2.0 * k3 + k4
        return position + temp / 6.0
    }
    
    func derivative(position: simd_double3) -> simd_double3 {
        var derivative = position
        derivative.x = xDerivative(position: position)
        derivative.y = yDerivative(position: position)
        derivative.z = zDerivative(position: position)
        return derivative
    }
    
    /// Derivative function of x using Lorentz's equations.
    func xDerivative(position: simd_double3) -> Double {
        return sigma * (position.y - position.x)
    }
    /// Derivative function of y using Lorentz's equations.
    func yDerivative(position: simd_double3) -> Double {
        return r * position.x - position.y - position.x * position.z
    }
    /// Derivative function of z using Lorentz's equations.
    func zDerivative(position: simd_double3) -> Double {
        return position.x * position.y - b * position.z
    }
}
