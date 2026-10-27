//
//  ZPLBox.swift
//  swift-zpl
//
//  Created by Damian Van de Kauter on 27/10/2026.
//

/// A rectangle drawn with `^GB`: a frame of the given thickness, a filled box when the thickness
/// reaches half the shorter side, or a line when one side equals the thickness.
public struct ZPLBox: Sendable, Hashable {
    public enum Color: Character, Sendable, Hashable, CaseIterable {
        case black = "B"
        case white = "W"
    }

    public var position: ZPLPosition
    /// Thickness…32000 dots.
    public var width: ZPLLength
    /// Thickness…32000 dots.
    public var height: ZPLLength
    /// Border thickness, 1…32000 dots.
    public var thickness: ZPLLength
    public var color: Color
    /// Corner rounding, 0 (square) … 8.
    public var cornerRounding: Int

    public init(
        at position: ZPLPosition,
        width: ZPLLength,
        height: ZPLLength,
        thickness: ZPLLength = 1,
        color: Color = .black,
        cornerRounding: Int = 0
    ) {
        self.position = position
        self.width = width
        self.height = height
        self.thickness = thickness
        self.color = color
        self.cornerRounding = cornerRounding
    }

    /// A horizontal line running right from the position.
    public static func horizontalLine(
        at position: ZPLPosition,
        length: ZPLLength,
        thickness: ZPLLength = 1,
        color: Color = .black
    ) -> ZPLBox {
        ZPLBox(at: position, width: length, height: thickness, thickness: thickness, color: color)
    }

    /// A vertical line running down from the position.
    public static func verticalLine(
        at position: ZPLPosition,
        length: ZPLLength,
        thickness: ZPLLength = 1,
        color: Color = .black
    ) -> ZPLBox {
        ZPLBox(at: position, width: thickness, height: length, thickness: thickness, color: color)
    }
}
