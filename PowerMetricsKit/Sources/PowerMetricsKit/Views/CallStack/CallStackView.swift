//
//  CallStackView.swift
//
//
//  Created by Raúl Montón Pinillos on 8/3/24.
//

import Foundation
import SwiftUI

final class BacktraceInfo {
    let address: BacktraceAddress
    let energy: Energy
    let info: SymbolicatedInfo?
    let children: BacktraceInfo?
    
    init(address: BacktraceAddress, energy: Energy, info: SymbolicatedInfo?, children: BacktraceInfo?) {
        self.address = address
        self.energy = energy
        self.info = info
        self.children = children
    }
}

@MainActor struct CallStackView: View {
    
    private let formattedCallStackData: [BacktraceInfo]
    let maxEnergyForSingleAddress: Energy
    let energyFormatter = NumberFormatter.power
    
    init(info: PowerWidgetInfo) {
        let formattedData = Self.getCallStacksByEnergy(info: info)
        self.formattedCallStackData = formattedData
        self.maxEnergyForSingleAddress = formattedData.map(\.energy).max() ?? .zero
    }
    
    var body: some View {
        List(formattedCallStackData, id: \.address) { backtraceInfo in
            HStack {
                Text(formatEnergy(energy: backtraceInfo.energy))
                    .frame(width: 72, alignment: .leading)
                Text("\(backtraceInfo.info?.symbolName ?? "Unknown")")
                    .frame(alignment: .leading)
            }
            .monospaced()
            .lineLimit(1)
        }
        .listStyle(.plain)
        .padding()
        .scrollContentBackground(.hidden)
    }
        
    private static func getCallStacksByEnergy(info: PowerWidgetInfo) -> [BacktraceInfo] {
        
        // Get the energy for every single memory address in all backtraces
        var energyResult = [BacktraceAddress: Energy]()
        for backtrace in info.backtraces {
            let energy = backtrace.energy ?? .zero
            for address in backtrace.addresses {
                if energyResult[address] != nil {
                    energyResult[address]? += energy
                } else {
                    energyResult[address] = energy
                }
            }
        }
        // Compute backtraces
        var symbolicatedResult = [BacktraceInfo]()
        for backtrace in info.backtraces {
            symbolicatedResult.append(createBacktraceInfo(for: backtrace.addresses, energies: energyResult))
        }
        return symbolicatedResult
    }
    
    private static func createBacktraceInfo(for addresses: [BacktraceAddress], energies: [BacktraceAddress: Energy]) -> BacktraceInfo {
        if let outermostAddress = addresses.last {
            let energy = energies[outermostAddress] ?? .zero
            let symbolicatedInfo = SymbolicateBacktraces.shared.symbolicatedInfo(for: outermostAddress)
            if addresses.count == 1 {
                return BacktraceInfo(
                    address: outermostAddress,
                    energy: energy,
                    info: symbolicatedInfo,
                    children: nil
                )
            } else {
                return BacktraceInfo(
                    address: outermostAddress, 
                    energy: energy,
                    info: symbolicatedInfo,
                    children: createBacktraceInfo(for: addresses.dropLast(), energies: energies)
                )
            }
        } else {
            return BacktraceInfo(address: .zero, energy: .zero, info: nil, children: nil)
        }
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
