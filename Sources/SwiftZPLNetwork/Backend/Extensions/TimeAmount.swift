//
//  TimeAmount.swift
//  swift-zpl
//
//  Created by Damian Van de Kauter on 27/10/2026.
//

import NIOCore

extension TimeAmount {
    init(_ duration: Duration) {
        let (seconds, attoseconds) = duration.components
        self = .nanoseconds(seconds * 1_000_000_000 + attoseconds / 1_000_000_000)
    }
}
