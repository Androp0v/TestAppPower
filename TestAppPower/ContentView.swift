//
//  ContentView.swift
//  TestAppPower
//
//  Created by Raúl Montón Pinillos on 14/1/24.
//

import SwiftUI

struct ContentView: View {
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State var isRunning: Bool = false
    @State var result: Double?
    
    var body: some View {
        let layout = horizontalSizeClass == .compact ? AnyLayout(VStackLayout()) : AnyLayout(HStackLayout())
        layout {
            PowerWidgetView()
                .frame(maxWidth: 300)
                .padding()
            VStack {
                SimulationView()
            }
            .padding()
        }
    }
}

#Preview {
    ContentView()
}
