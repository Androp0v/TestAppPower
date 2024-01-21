//
//  ContentView.swift
//  TestAppPower
//
//  Created by Raúl Montón Pinillos on 14/1/24.
//

import SwiftUI

struct ContentView: View {
    
    @State var isRunning: Bool = false
    @State var result: Double?
    
    var body: some View {
        VStack {
            PowerWidgetView()
                .frame(maxWidth: 300)
                .padding()
            VStack {
                HStack(spacing: 12) {
                    if isRunning {
                        ProgressView()
                    }
                    Button(
                        action: {
                            withAnimation {
                                isRunning = true
                            }
                            Task.detached(priority: .userInitiated) {
                                let newResult = await longRunningTaskMulticore()
                                withAnimation {
                                    self.result = newResult
                                    isRunning = false
                                }
                            }
                        },
                        label: {
                            Image(systemName: "gauge.with.dots.needle.100percent")
                                .imageScale(.large)
                            Text("Start long running task")
                        }
                    )
                    .disabled(isRunning)
                }
                if let result {
                    Text("Result: \(result)")
                }
            }
            .padding()
        }
    }
    
    func longRunningTaskMulticore() async -> Double {
        return await withTaskGroup(of: Double.self) { group in
            var result: Double = 0
            for task in 0..<16 {
                group.addTask {
                    return longRunningTask()
                }
            }
            for await value in group {
                result += value
            }
            return result
        }
    }
    
    func longRunningTask() -> Double {
        var x: Double = 0
        var y: Double = 0
        for _ in 0..<10_000_000 {
            x += Double.random(in: 0..<1) - 0.5
            y += Double.random(in: 0..<1) - 0.5
        }
        return x + y
    }
}

#Preview {
    ContentView()
}
