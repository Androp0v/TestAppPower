//
//  File.swift
//  
//
//  Created by Raúl Montón Pinillos on 3/2/24.
//

import Foundation

struct SampleThreadsResult: Identifiable {
    let id = UUID()
    let time: Date
    let combinedPower: CombinedPower
    
    static var zero: SampleThreadsResult {
        return SampleThreadsResult(time: .now, combinedPower: .zero)
    }
}
