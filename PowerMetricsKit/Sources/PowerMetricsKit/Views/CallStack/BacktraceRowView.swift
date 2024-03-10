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
    @Binding var expandedInfos: [BacktraceInfo]
    
    var isExpanded: Bool {
        return expandedInfos.contains(where: { $0.id == backtraceInfo.id })
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            backtraceRow(backtraceInfo: backtraceInfo)
        }
    }
    
    @ViewBuilder func backtraceRow(backtraceInfo: BacktraceInfo) -> some View {
        HStack {
            Button(
                action: {
                    withAnimation {
                        if isExpanded {
                            expandedInfos = expandedInfos.dropLast()
                        } else {
                            expandedInfos.append(backtraceInfo)
                        }
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
            .buttonStyle(.plain)
            BacktraceRowContentView(
                symbolInfo: backtraceInfo.info,
                energy: backtraceInfo.energy
            )
        }
    }
}
