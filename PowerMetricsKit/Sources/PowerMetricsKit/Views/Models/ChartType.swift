//
//  File.swift
//  
//
//  Created by Raúl Montón Pinillos on 4/2/24.
//

import Foundation

enum ChartType: CaseIterable {
    case coreType
    case thread
    
    var displayName: String {
        switch self {
        case .coreType:
            return "Per core type"
        case .thread:
            return "Per thread"
        }
    }
}
