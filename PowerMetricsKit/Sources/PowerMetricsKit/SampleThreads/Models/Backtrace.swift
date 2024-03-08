//
//  Backtrace.swift
//
//
//  Created by Raúl Montón Pinillos on 8/3/24.
//

import Foundation

public typealias BacktraceAddress = UInt64

public struct Backtrace: Hashable, Equatable {
    public let addresses: [BacktraceAddress]
    public let energy: Energy?
}
