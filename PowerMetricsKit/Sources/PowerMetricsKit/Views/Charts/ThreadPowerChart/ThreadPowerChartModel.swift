//
//  ThreadPowerChartModel.swift
//
//
//  Created by Raúl Montón Pinillos on 10/2/24.
//

import Foundation
import SwiftUI

@MainActor @Observable class ThreadPowerChartModel {
    
    var threadColors = [String: Color]()
    
    init(){}
    
    func colorForDisplayName(_ displayName: String, environment: EnvironmentValues) -> Color {
        if let existingColor = threadColors[displayName] {
            return existingColor
        }
        let randomColor: Color = .newChartColor(existing: Array(threadColors.values), environment: environment)
        threadColors[displayName] = randomColor
        return randomColor
    }
}
