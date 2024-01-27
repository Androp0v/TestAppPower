//
//  SampleGPUManager.swift
//  TestAppPower
//
//  Created by Raúl Montón Pinillos on 27/1/24.
//

import Foundation

class SampleGPUManager {
    
    var historicEnergy = [Double]()
    
    private init(){}
    static let shared = SampleGPUManager()

    func sampleGPUPower() -> Double? {
        let currentEnergy = sample_gpu()
        
        guard !currentEnergy.isNaN else {
            return nil
        }
        
        if let previousEnergy = historicEnergy.last {
            let power = (currentEnergy - previousEnergy) / 0.5
            historicEnergy.append(currentEnergy)
            return power
        } else {
            historicEnergy.append(currentEnergy)
            return nil
        }
    }
}
