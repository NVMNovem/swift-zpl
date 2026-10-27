//
//  ZPLOrientation.swift
//  swift-zpl
//
//  Created by Damian Van de Kauter on 27/10/2026.
//

/// How a field is rotated on the label, clockwise.
public enum ZPLOrientation: Character, Sendable, Hashable, CaseIterable {
    /// `N`
    case normal = "N"
    /// `R` — rotated 90°.
    case rotated = "R"
    /// `I` — rotated 180°.
    case inverted = "I"
    /// `B` — rotated 270°, read from the bottom up.
    case bottomUp = "B"
}
