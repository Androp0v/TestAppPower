//
//  SymbolicateBacktraces.swift
//
//
//  Created by Raúl Montón Pinillos on 9/3/24.
//

import Foundation
import SampleThreads

struct DYLDInfo {
    let index: Int
    let name: String
    let loadAddress: intptr_t
    let aslrSlide: intptr_t
}

struct SymbolicatedInfo: Hashable {
    let imageName: String
    let addressInImage: UInt64
    let symbolName: String
    let addressInSymbol: UInt64
    
    var displayName: String {
        return "0x\(String(format: "%llx", addressInImage)), \(imageName)"
    }
}

class SymbolicateBacktraces {
        
    private init() {}
    public static let shared = SymbolicateBacktraces()
    
    func symbolicatedInfo(for address: UInt64) -> SymbolicatedInfo? {
        
        var dlInfo = Dl_info()
        let addressPointer = UnsafeRawPointer(bitPattern: UInt(address))
        if dladdr(addressPointer, &dlInfo) != 0 {
            let imageName = (String(cString: dlInfo.dli_fname) as NSString).lastPathComponent
            let addressInImage = address - (unsafeBitCast(dlInfo.dli_fbase, to: UInt64.self))
            let symbolName = (String(cString: dlInfo.dli_sname) as NSString).lastPathComponent
            let addressInSymbol = address - (unsafeBitCast(dlInfo.dli_saddr, to: UInt64.self))
            return SymbolicatedInfo(
                imageName: imageName,
                addressInImage: addressInImage,
                symbolName: symbolName,
                addressInSymbol: addressInSymbol
            )
        } else {
            // dladdr returns 0 on error
            return nil
        }
    }
}
