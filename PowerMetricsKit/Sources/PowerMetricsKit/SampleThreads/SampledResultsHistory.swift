//
//  File.swift
//  
//
//  Created by Raúl Montón Pinillos on 3/2/24.
//

import Foundation

/// Historic power figures for the app.
class SampledResultsHistory {
    
    let numberOfStoredSamples: Int = 60
    
    var maxPower: Power = .zero
    var samples = [SampleThreadsResult]()
        
    private var ringBuffer = [SampleThreadsResult](repeating: .zero, count: 60)
    private var writeIndex: Int = 0
    private var displayableSamples: Int = 0
    
    init() {}
    
    func addSample(_ sample: SampleThreadsResult) {
        
        ringBuffer[writeIndex] = sample
        
        writeIndex += 1
        writeIndex = writeIndex % numberOfStoredSamples
        
        samples = ringBuffer.sorted(by: { $0.time < $1.time })
        maxPower = ringBuffer.map({$0.combinedPower.total}).max() ?? .zero
    }
}
