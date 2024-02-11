//
//  ThreadPowerRow.swift
//
//
//  Created by Raúl Montón Pinillos on 10/2/24.
//

import SwiftUI

struct ThreadPowerRow: View {
    
    let thread: ThreadSample
    let threadColor: Color
    let hasUpToDatePower: Bool
    
    var powerText: String {
        if hasUpToDatePower {
            return "\(NumberFormatter.power.string(for: 1000 * thread.power.total) ?? "??") mW"
        } else {
            return "- mW"
        }
    }
        
    var body: some View {
        HStack {
            Circle()
                .frame(width: 8, height: 8)
                .foregroundStyle(threadColor)
            Text(thread.displayName)
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundStyle(threadColor)
            Text(powerText)
                .foregroundStyle(.secondary)
                .font(.caption)
                .monospaced()
        }
    }
}
