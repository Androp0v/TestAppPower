//
//  BacktraceRowContentView.swift
//
//
//  Created by Raúl Montón Pinillos on 10/3/24.
//

import SwiftUI

struct BacktraceRowContentView: View {
    
    let symbolInfo: SymbolicatedInfo?
    let energy: Energy
    let energyFormatter = NumberFormatter.power
    
    var body: some View {
        HStack {
            Text(formatEnergy(energy: energy))
                .frame(width: 81, alignment: .leading)
            Text("\(symbolInfo?.symbolName ?? "Unknown")")
                .frame(alignment: .leading)
        }
        .monospaced()
        .lineLimit(1)
    }
    
    func formatEnergy(energy: Energy) -> String {
        if energy < 0.1 {
            let energy = NSNumber(value: energy * 1000)
            return (energyFormatter.string(from: energy) ?? "?") + " mWh"
        } else {
            let energy = NSNumber(value: energy)
            return (energyFormatter.string(from: energy) ?? "?") + " Wh"
        }
    }
}

