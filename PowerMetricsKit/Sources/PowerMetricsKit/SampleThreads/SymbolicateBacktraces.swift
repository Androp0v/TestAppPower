//
//  SymbolicateBacktraces.swift
//
//
//  Created by Raúl Montón Pinillos on 9/3/24.
//

import Foundation
import SampleThreads

public class SymbolicateBacktraces {
    
    public var backtraceGraph = BacktraceGraph()
    public var flatBacktraces = [SimpleBacktraceInfo]()
    private var addressToBacktrace = [BacktraceAddress: BacktraceInfo]()
        
    private init() {}
    public static let shared = SymbolicateBacktraces()
    
    public func symbolicatedInfo(for address: UInt64) -> SymbolicatedInfo? {
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
    
    /*
    func createBacktraceInfo(for addresses: [BacktraceAddress]) -> BacktraceInfo {
        if let outermostAddress = addresses.last {
            if outermostAddress == .zero {
                return createBacktraceInfo(for: addresses.dropLast())
            }
            let symbolicatedInfo = SymbolicateBacktraces.shared.symbolicatedInfo(for: outermostAddress)
            let backtraceInfo = BacktraceInfo(
                address: outermostAddress,
                energy: .zero,
                info: symbolicatedInfo,
                children: []
            )
            if addresses.count != 1 {
                backtraceInfo.children = [createBacktraceInfo(for: addresses.dropLast())]
            }
            return backtraceInfo
        } else {
            return BacktraceInfo(address: .zero, energy: .zero, info: nil, children: [])
        }
    }
    
    private func addAddressesFromBacktraceInfo(_ backtraceInfo: BacktraceInfo?) {
        var newChildren: BacktraceInfo? = backtraceInfo
        while true {
            guard let child = newChildren else {
                break
            }
            if addressToBacktrace[child.address] == nil {
                addressToBacktrace[child.address] = newChildren
            }
            newChildren = newChildren?.children.first
        }
    }
    */
    
    func addToBacktraceGraph(_ backtraces: [Backtrace]) {
        for backtrace in backtraces {
            backtraceGraph.insertInGraph(newBacktrace: backtrace)
        }
        /*
        for backtrace in backtraces {
            guard let outermostAddress = backtrace.addresses.last else {
                // Empty backtrace, move on...
                continue
            }
            if let existingInfo = addressToBacktrace[outermostAddress] {
                let newBacktraceInfo = createBacktraceInfo(
                    for: backtrace.addresses
                )
                var existingInfoLoop = existingInfo
                var existingChildrenLoop = existingInfoLoop.children
                var newInfoLoop = newBacktraceInfo
                var newChildrenLoop = newBacktraceInfo.children.first
                while true {
                    guard let newChildren = newChildrenLoop else {
                        // No more children in the backtrace
                        break
                    }
                    if existingChildrenLoop.isEmpty {
                        // Existing backtrace doesn't contain any child
                        existingInfoLoop.children.append(newChildren)
                        addAddressesFromBacktraceInfo(newChildren)
                        break
                    } else if existingChildrenLoop.contains(where: { $0.address == newChildren.address }) {
                        // Existing backtrace info contains the same children
                        existingChildrenLoop = existingChildrenLoop.flatMap({ $0.children })
                        newChildrenLoop = newChildren.children.first
                    } else {
                        // Existing backtrace doesn't contain this child
                        existingInfoLoop.children.append(newChildren)
                        addAddressesFromBacktraceInfo(newChildren)
                        break
                    }
                }
                addressToBacktrace[outermostAddress] = newBacktraceInfo
            } else {
                // Doesn't exist, must be a new top-level backtrace
                let newBacktraceInfo = createBacktraceInfo(
                    for: backtrace.addresses
                )
                backtraceGraph.append(newBacktraceInfo)
                addressToBacktrace[outermostAddress] = newBacktraceInfo
            }
        }
        */
        
        // Get the energy for every single memory address in all new backtraces
        for backtrace in backtraces {
            guard let energy = backtrace.energy else {
                // Backtrace doesn't contain any energy information...
                continue
            }
            // Add energies to backtrace graph
            /*
            for address in backtrace.addresses {
                guard let backtraceInfo = addressToBacktrace[address] else {
                    print("Error: backtrace info missing for address")
                    continue
                }
                backtraceInfo.energy += energy
            }
             */
            // Add energies to backtrace flatmap
            for address in backtrace.addresses {
                if let existingInfo = flatBacktraces.first(where: { $0.address == address }) {
                    existingInfo.energy += energy
                } else {
                    flatBacktraces.append(SimpleBacktraceInfo(
                        address: address,
                        energy: energy,
                        info: symbolicatedInfo(for: address)
                    ))
                }
            }
        }
    }
}
