//
//  File.swift
//  
//
//  Created by Raúl Montón Pinillos on 3/2/24.
//

import Foundation

/// The power used by a single thread.
public struct ThreadPower {
    /// The Mach thread ID.
    let threadID: UInt64
    /// The pthread name of the thread.
    let pthreadName: String?
    /// The combined power used by this thread in the interval across all core types.
    let power: CombinedPower
    /// The name of this thread when displayed in the UI. Matched the `pthreadName` (if available),
    /// defaults to the `threadID` otherwise.
    var displayName: String {
        if let pthreadName {
            return pthreadName
        }
        return String("\(threadID)")
    }
    
    init(threadID: UInt64, pthreadName: String?, power: CombinedPower) {
        self.threadID = threadID
        if let pthreadName, !pthreadName.isEmpty {
            self.pthreadName = pthreadName
        } else {
            self.pthreadName = nil
        }
        self.power = power
    }
}

/// The processed results from sampling the threads.
public struct SampleThreadsResult: Identifiable {
    /// Unique identifier for the sample.
    public let id = UUID()
    /// The time at which the measurement was performed.
    public let time: Date
    /// The combined power used in the interval by all threads.
    public let allThreadsPower: CombinedPower
    
    public let threadsPower: [ThreadPower]
    
    /// Empty sample with zero power.
    public static var zero: SampleThreadsResult {
        return SampleThreadsResult(
            time: .now,
            allThreadsPower: .zero,
            threadsPower: [ThreadPower]()
        )
    }
}
