//
//  CallStackView.swift
//
//
//  Created by Raúl Montón Pinillos on 8/3/24.
//

import Foundation
import SwiftUI

@MainActor struct CallStackView: View {
    
    enum VisualizationMode {
        case graph
        case flat
    }
    
    let symbolicator = SymbolicateBacktraces.shared
    @State var expandedAddresses = [BacktraceAddress: Bool]()
    @State var visualizationMode: VisualizationMode = .flat
    
    var sortedGraphBacktraces: [BacktraceInfo] {
        return symbolicator.backtraceGraph.nodes.sorted(by: { $0.energy > $1.energy })
    }
    var sortedFlatBacktraces: [SimpleBacktraceInfo] {
        return symbolicator.flatBacktraces.sorted(by: { $0.energy > $1.energy })
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: .zero) {
            TimelineView(.periodic(from: .now, by: 0.5)) { _ in
                if visualizationMode == .graph {
                    List(sortedGraphBacktraces, id: \.id) { backtraceInfo in
                        BacktraceRowView(
                            backtraceInfo: backtraceInfo,
                            energy: backtraceInfo.energy,
                            expandedAddresses: $expandedAddresses
                        )
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                } else {
                    List(sortedFlatBacktraces, id: \.address) { simpleBacktraceInfo in
                        BacktraceRowContentView(
                            symbolInfo: simpleBacktraceInfo.info,
                            energy: simpleBacktraceInfo.energy
                        )
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            
            Divider()
            Button(
                action: {
                    if visualizationMode == .graph {
                        visualizationMode = .flat
                    } else {
                        visualizationMode = .graph
                    }
                },
                label: {
                    Image(systemName: visualizationMode == .flat
                          ? "list.bullet.indent"
                          : "list.bullet"
                    )
                }
            )
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
        .padding()
    }
}
