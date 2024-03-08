//
//  CallStackView.swift
//
//
//  Created by Raúl Montón Pinillos on 8/3/24.
//

import Foundation
import SwiftUI

@MainActor struct CallStackView: View {
    
    let energyFormatter = NumberFormatter.power
    let formattedCallStackData: [(BacktraceAddress, Energy)]
    let maxEnergyForSingleAddress: Energy
    
    init(info: PowerWidgetInfo) {
        let formattedData = Self.getCallStacksByEnergy(info: info)
        self.formattedCallStackData = formattedData
        self.maxEnergyForSingleAddress = formattedData.map(\.1).max() ?? .zero
    }
    
    var body: some View {
        List(formattedCallStackData, id: \.0) { backtraceAddress, energy in
            HStack {
                Text(formatEnergy(energy: energy))
                Spacer()
                Text("0x\(String(format: "%llx", backtraceAddress))")
            }
            .monospaced()
        }
        .listStyle(.plain)
        .padding()
        .scrollContentBackground(.hidden)
    }
        
    static func getCallStacksByEnergy(info: PowerWidgetInfo) -> [(BacktraceAddress, Energy)] {
        var result = [BacktraceAddress: Energy]()
        for backtrace in info.backtraces {
            let energy = backtrace.energy ?? .zero
            for address in backtrace.addresses {
                if result[address] != nil {
                    result[address]? += energy
                } else {
                    result[address] = energy
                }
            }
        }
        return Array(result).sorted(by: { $0.value > $1.value })
    }
    
    func formatEnergy(energy: Energy) -> String {
        if maxEnergyForSingleAddress < 0.1 {
            let energy = NSNumber(value: energy * 1000)
            return (energyFormatter.string(from: energy) ?? "?") + " mWh"
        } else {
            let energy = NSNumber(value: energy)
            return (energyFormatter.string(from: energy) ?? "?") + " Wh"
        }
    }
}
