//
//  CallStackView.swift
//
//
//  Created by Raúl Montón Pinillos on 8/3/24.
//

import Foundation
import SwiftUI

@MainActor struct CallStackView: View {
    
    enum VisualizationMode: String {
        case graph
        case flat
    }
    
    let symbolicator = SymbolicateBacktraces.shared
    @State var expandedInfos = [BacktraceInfo]()
    @AppStorage("callstackVisualization") var visualizationMode: VisualizationMode = .graph
    
    var sortedGraphBacktraces: [BacktraceInfo] {
        if let lastExpanded = expandedInfos.last {
            return lastExpanded.children
                .sorted(by: { $0.energy > $1.energy })
        } else {
            return symbolicator.backtraceGraph.nodes
                .sorted(by: { $0.energy > $1.energy })
        }
    }
    var sortedFlatBacktraces: [SimpleBacktraceInfo] {
        return symbolicator.flatBacktraces.sorted(by: { $0.energy > $1.energy })
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: .zero) {
            Divider()
            
            TimelineView(.periodic(from: .now, by: 0.5)) { _ in
                if visualizationMode == .graph {
                    VStack(alignment: .leading, spacing: .zero) {
                        if let lastExpanded = expandedInfos.last {
                            BacktraceRowView(
                                backtraceInfo: lastExpanded,
                                energy: lastExpanded.energy,
                                expandedInfos: $expandedInfos
                            )
                            #if os(macOS)
                            .padding(.vertical, 4)
                            .padding(.horizontal, 4)
                            #else
                            .padding(.vertical, 12)
                            .padding(.horizontal, 12)
                            #endif
                            .background(.blue.opacity(0.3))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .padding(.top, 4)
                        }

                        List(sortedGraphBacktraces, id: \.id) { backtraceInfo in
                            BacktraceRowView(
                                backtraceInfo: backtraceInfo,
                                energy: backtraceInfo.energy,
                                expandedInfos: $expandedInfos
                            )
                            .listRowBackground(Color.clear)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                } else {
                    List(sortedFlatBacktraces, id: \.address) { simpleBacktraceInfo in
                        BacktraceRowContentView(
                            symbolInfo: simpleBacktraceInfo.info,
                            energy: simpleBacktraceInfo.energy
                        )
                        .listRowBackground(Color.clear)
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
            #if os(macOS)
            .buttonStyle(.plain)
            #endif
            .padding(.top, 8)
        }
        .padding()
    }
}
