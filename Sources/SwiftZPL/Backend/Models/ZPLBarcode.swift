//
//  ZPLBarcode.swift
//  swift-zpl
//
//  Created by Damian Van de Kauter on 27/10/2026.
//

/// A linear barcode drawn by the printer.
///
/// The data is checked against the symbology when the label is encoded, so a value the symbology
/// cannot hold fails with ``ZPLEncodingError/invalidBarcodeData(_:_:)`` instead of printing a
/// barcode that scans as something else.
public struct ZPLBarcode: Sendable, Hashable {
    public enum Symbology: Sendable, Hashable {
        /// `^BC`, automatic subset selection. Printable ASCII except `>`, which ZPL reserves for
        /// subset switching.
        case code128
        /// `^B3`. Digits, upper-case letters, space and `- . $ / + %`; `checkDigit` adds the
        /// modulo-43 check character.
        case code39(checkDigit: Bool)
        /// `^BE`. Twelve digits, or thirteen with a correct check digit; the printer computes the
        /// check digit itself.
        case ean13
    }

    /// Where the human-readable line is printed.
    public enum Interpretation: Sendable, Hashable, CaseIterable {
        case none
        case below
        case above
    }

    public var symbology: Symbology
    public var data: String
    public var position: ZPLPosition
    /// Bar height, 1…32000 dots.
    public var height: ZPLLength
    /// Width of the narrowest bar (`^BY`), 1…10 dots.
    public var moduleWidth: Int
    /// Wide to narrow bar ratio for Code 39, 2.0…3.0 in steps of 0.1. Ignored by the others.
    public var wideBarRatio: Double
    public var orientation: ZPLOrientation
    public var interpretation: Interpretation

    public init(
        _ symbology: Symbology,
        data: String,
        at position: ZPLPosition,
        height: ZPLLength,
        moduleWidth: Int = 2,
        wideBarRatio: Double = 3.0,
        orientation: ZPLOrientation = .normal,
        interpretation: Interpretation = .below
    ) {
        self.symbology = symbology
        self.data = data
        self.position = position
        self.height = height
        self.moduleWidth = moduleWidth
        self.wideBarRatio = wideBarRatio
        self.orientation = orientation
        self.interpretation = interpretation
    }

    public static func code128(
        _ data: String,
        at position: ZPLPosition,
        height: ZPLLength,
        moduleWidth: Int = 2,
        orientation: ZPLOrientation = .normal,
        interpretation: Interpretation = .below
    ) -> ZPLBarcode {
        ZPLBarcode(
            .code128, data: data, at: position, height: height, moduleWidth: moduleWidth,
            orientation: orientation, interpretation: interpretation
        )
    }

    public static func code39(
        _ data: String,
        at position: ZPLPosition,
        height: ZPLLength,
        checkDigit: Bool = false,
        moduleWidth: Int = 2,
        wideBarRatio: Double = 3.0,
        orientation: ZPLOrientation = .normal,
        interpretation: Interpretation = .below
    ) -> ZPLBarcode {
        ZPLBarcode(
            .code39(checkDigit: checkDigit), data: data, at: position, height: height,
            moduleWidth: moduleWidth, wideBarRatio: wideBarRatio, orientation: orientation,
            interpretation: interpretation
        )
    }

    public static func ean13(
        _ data: String,
        at position: ZPLPosition,
        height: ZPLLength,
        moduleWidth: Int = 2,
        orientation: ZPLOrientation = .normal,
        interpretation: Interpretation = .below
    ) -> ZPLBarcode {
        ZPLBarcode(
            .ean13, data: data, at: position, height: height, moduleWidth: moduleWidth,
            orientation: orientation, interpretation: interpretation
        )
    }
}
