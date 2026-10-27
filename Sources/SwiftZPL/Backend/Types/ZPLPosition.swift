//
//  ZPLPosition.swift
//  swift-zpl
//
//  Created by Damian Van de Kauter on 27/10/2026.
//

/// A point on the label, measured from the label home (`^LH`, the top-left corner by default):
/// `x` to the right, `y` down.
public struct ZPLPosition: Sendable, Hashable {
    public var x: ZPLLength
    public var y: ZPLLength

    public init(x: ZPLLength, y: ZPLLength) {
        self.x = x
        self.y = y
    }

    public static let zero = ZPLPosition(x: 0, y: 0)
}
