//
//  File.swift
//  
//
//  Created by Raúl Montón Pinillos on 3/2/24.
//

import Foundation

/// A power measurement, always in watts.
typealias Power = Double
/// An energy measurement, always in watts-hour.
typealias Energy = Double

struct CombinedPower {
    
    static var zero: CombinedPower {
        return CombinedPower(performance: .zero, efficiency: .zero)
    }
    
    let performance: Power
    let efficiency: Power
    
    var total: Power {
        return performance + efficiency
    }
}

// MARK: - Formatting

struct ChartPowerFormatStyle {
    
    struct Watts: FormatStyle {
        
        static var formatter: NumberFormatter = {
            let numberFormatter = NumberFormatter()
            numberFormatter.minimumFractionDigits = 1
            return numberFormatter
        }()
        
        func format(_ value: Power) -> String {
            let power = NSNumber(value: value)
            return Self.formatter.string(from: power) ?? "??"
        }
    }
    
    struct Miliwatts: FormatStyle {
        
        static var formatter: NumberFormatter = {
            let numberFormatter = NumberFormatter()
            numberFormatter.maximumFractionDigits = 0
            return numberFormatter
        }()
        
        func format(_ value: Power) -> String {
            let power = NSNumber(value: value * 1000)
            return Self.formatter.string(from: power) ?? "??"
        }
    }
}
