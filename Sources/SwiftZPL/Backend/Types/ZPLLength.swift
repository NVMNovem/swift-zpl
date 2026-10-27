//
//  ZPLLength.swift
//  swift-zpl
//
//  Created by Damian Van de Kauter on 27/10/2026.
//

/// A distance on the label, in dots or in a physical unit.
///
/// Dots are what ZPL speaks. Millimetres and inches are converted with the resolution of the
/// ``ZPLProfile`` the label is encoded for, never with an assumed 203 dpi, and rounded to the
/// nearest dot with halves rounded away from zero: at 203 dpi `.millimeters(10)` is 80 dots and
/// `.millimeters(0.0625)` is 1. Each length is rounded on its own, so two lengths that add up on
/// paper may differ by a dot once converted.
///
/// An integer literal is a number of dots.
public enum ZPLLength: Sendable, Hashable, ExpressibleByIntegerLiteral {
    case dots(Int)
    case millimeters(Double)
    case inches(Double)

    public init(integerLiteral value: Int) {
        self = .dots(value)
    }

    /// The length in whole dots at a resolution, or `nil` when it is not a finite number or too
    /// large to count.
    public func dots(at resolution: ZPLResolution) -> Int? {
        switch self {
        case .dots(let dots):
            dots
        case .millimeters(let millimeters):
            Self.wholeDots(millimeters * resolution.dotsPerMillimeter)
        case .inches(let inches):
            Self.wholeDots(inches * resolution.dotsPerInch)
        }
    }

    private static func wholeDots(_ value: Double) -> Int? {
        let rounded = value.rounded(.toNearestOrAwayFromZero)
        guard rounded.isFinite, rounded.magnitude < 1e15 else { return nil }
        return Int(rounded)
    }
}
