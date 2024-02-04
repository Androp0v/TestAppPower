//
//  SampleThreadsManager.swift
//  TestAppPower
//
//  Created by Raúl Montón Pinillos on 20/1/24.
//

import Foundation
import SampleThreads

/// The global actor used to access the `SampleThreadsManager` in a thread-safe way.
@globalActor public actor SampleThreadsActor {
    public static let shared = SampleThreadsActor()
}

/// The main class interfacing with the C code that retrieves the energy data.
@SampleThreadsActor public class SampleThreadsManager {
    
    // MARK: - Public properties
    
    /// The timespan between each sample.
    public static let samplingTime: TimeInterval = 0.5
    /// The number of samples kept in the history.
    public static let numberOfStoredSamples: Int = 60
    
    /// The total count of threads spawned by the app.
    public private(set) var currentThreadCount: Int = 1
    /// Total energy used by the app since launch, in Watts-hour.
    public private(set) var totalEnergyUsage: Energy = 0
    /// Historic power figures for the app.
    public private(set) var history = SampledResultsHistory(numerOfStoredSamples: SampleThreadsManager.numberOfStoredSamples)
    
    // MARK: - Private properties
    
    private var samplingTask: Task<Void, Never>?
    private var continuousClock = ContinuousClock()
    private var lastSampleTime: ContinuousClock.Instant?
    private var previousCounters = [UInt64: thread_counters_t]()

    // MARK: - Init
    
    private init(){}
    public static let shared = SampleThreadsManager()
    
    // MARK: - Sampling
    
    /// Starts sampling CPU power used for the given PID.
    /// - Parameter pid: PID of the process to sample.
    public func startSampling(pid: Int32) {
        guard self.samplingTask == nil else {
            return
        }
        self.samplingTask = Task(priority: .high) { [weak self] in
            while !Task.isCancelled {
                guard let self else {
                    return
                }
                self.sampleThreads(pid)
                try? await Task.sleep(
                    for: .seconds(Self.samplingTime),
                    tolerance: .seconds(Self.samplingTime * 0.01)
                )
            }
        }
    }
    
    /// Stop sampling threads.
    public func stopSampling() {
        self.samplingTask?.cancel()
    }
    
    /// Given the pid for a process, sample all the threads belonging to that process and
    /// return the `CombinedPower` used for that process.
    /// - Parameter pid: The pid of the process to inspect.
    /// - Returns: The `CombinedPower` used by that process.
    @discardableResult public func sampleThreads(_ pid: Int32) -> SampleThreadsResult {
        let currentSampleTime = continuousClock.now
        // Invoke the C code in sample_threads.c that uses proc_pidinfo to retrieve
        // performance counters including energy usage.
        let result = sample_threads(pid)
        // This points directly to the C array.
        let counters = UnsafeBufferPointer(start: result.cpu_counters, count: Int(result.thread_count))
        // This creates a Swift copy of the C array.
        let countersArray = [thread_counters_t](counters)
        // Free the memory allocated with malloc in sample_threads.c, as we've created
        // a copy for Swift code.
        free(result.cpu_counters)
                
        var combinedPPower = 0.0
        var combinedEPower = 0.0
        for counter in countersArray {
            if let previousCounter = previousCounters[counter.thread_id], let lastSampleTime {
                let performancePower = computePower(
                    previousTime: lastSampleTime,
                    currentTime: currentSampleTime,
                    previousCounters: previousCounter,
                    currentCounter: counter,
                    type: .performance
                )
                let efficiencyPower = computePower(
                    previousTime: lastSampleTime,
                    currentTime: currentSampleTime,
                    previousCounters: previousCounter,
                    currentCounter: counter,
                    type: .efficiency
                )
                combinedPPower += performancePower
                combinedEPower += efficiencyPower
            }
        }
        
        // Reset previous counters with the latest samples
        self.previousCounters = [UInt64: thread_counters_t]()
        for counter in countersArray {
            self.previousCounters[counter.thread_id] = counter
        }
        
        self.lastSampleTime = currentSampleTime
        self.currentThreadCount = Int(result.thread_count)
        let sampleResult = SampleThreadsResult(
            time: .now,
            combinedPower: CombinedPower(
                performance: combinedPPower,
                efficiency: combinedEPower
            )
        )
        
        self.history.addSample(sampleResult)
        self.totalEnergyUsage += sampleResult.combinedPower.total * Self.samplingTime / 3600
        return sampleResult
    }
    
    // MARK: - Energy
    
    public func resetEnergyUsed() {
        self.totalEnergyUsage = .zero
    }
    
    // MARK: - Private
    
    private func computePower(
        previousTime: ContinuousClock.Instant,
        currentTime: ContinuousClock.Instant,
        previousCounters: thread_counters_t,
        currentCounter: thread_counters_t,
        type: CoreType
    ) -> Double {
        let energyChange: Double
        switch type {
        case .performance:
            energyChange = currentCounter.performance.energy - previousCounters.performance.energy
        case .efficiency:
            energyChange = currentCounter.efficiency.energy - previousCounters.efficiency.energy
        }
        if !energyChange.isZero {
            // The *power* used during a time interval is the *total* energy consumed
            // divided by the time between measurements. Using the counters' ptcd times
            // instead would NOT yield the correct result, as that excludes times where
            // the threads were not running.
            //
            // If the sampling could be guaranteed to be done with precise timing, one
            // could also divide by SampleThreadsManager.samplingTime, but anything that
            // messes with the schedule at which sampleThreads() is called is going to
            // give wrong results (ie: suspending the app, stopping at a breakpoint
            // while debugging...).
            let elapsedTime = currentTime - previousTime
            let elapsedSeconds = Double(elapsedTime.components.seconds) + Double(elapsedTime.components.attoseconds) * 1e-18
            return energyChange / elapsedSeconds
        } else {
            return .zero
        }
    }
}
