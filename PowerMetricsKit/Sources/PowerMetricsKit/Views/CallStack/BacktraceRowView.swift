//
//  BacktraceRowView.swift
//
//
//  Created by Raúl Montón Pinillos on 9/3/24.
//

import SwiftUI

struct BacktraceRowView: View {
    
    let backtraceInfo: BacktraceInfo
    let energy: Energy
    @Binding var expandedAddresses: [BacktraceAddress: Bool]
    
    var isExpanded: Bool {
        return expandedAddresses[backtraceInfo.address] == true
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            backtraceRow(backtraceInfo: backtraceInfo)
            if isExpanded {
                ForEach(backtraceInfo.children) { children in
                    BacktraceRowView(
                        backtraceInfo: children,
                        energy: children.energy,
                        expandedAddresses: $expandedAddresses
                    )
                    .padding(.leading, 2)
                }
            }
        }
    }
    
    @ViewBuilder func backtraceRow(backtraceInfo: BacktraceInfo) -> some View {
        HStack {
            Button(
                action: {
                    if isExpanded {
                        expandedAddresses[backtraceInfo.address] = false
                    } else {
                        expandedAddresses[backtraceInfo.address] = true
                    }
                },
                label: {
                    Image(
                        systemName: isExpanded
                        ? "rectangle.compress.vertical"
                        : "rectangle.expand.vertical"
                    )
                }
            )
            BacktraceRowContentView(
                symbolInfo: backtraceInfo.info,
                energy: backtraceInfo.energy
            )
        }
    }
}
