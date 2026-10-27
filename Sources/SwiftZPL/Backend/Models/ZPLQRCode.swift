//
//  ZPLQRCode.swift
//  swift-zpl
//
//  Created by Damian Van de Kauter on 27/10/2026.
//

/// A QR code (model 2) drawn by the printer (`^BQ`), with automatic input mode.
///
/// The data is written in the label's character set, like any field data, so with
/// ``ZPLCharacterEncoding/utf8`` a scanner reads UTF-8. Line breaks are kept as line feeds.
///
/// Zebra printers place a QR code a few dots below its `^FO` position; the offset is the
/// printer's, and this library does not correct for it.
public struct ZPLQRCode: Sendable, Hashable {
    /// The share of the symbol that may be damaged and still read.
    public enum ErrorCorrection: Character, Sendable, Hashable, CaseIterable {
        /// About 7 %.
        case low = "L"
        /// About 15 %.
        case medium = "M"
        /// About 25 %.
        case quartile = "Q"
        /// About 30 %.
        case high = "H"

        /// The most bytes a version 40 symbol holds at this level in byte mode.
        public var maximumByteCount: Int {
            switch self {
            case .low: 2953
            case .medium: 2331
            case .quartile: 1663
            case .high: 1273
            }
        }
    }

    public var data: String
    public var position: ZPLPosition
    /// Dots per module, 1…10.
    public var magnification: Int
    public var errorCorrection: ErrorCorrection

    public init(
        _ data: String,
        at position: ZPLPosition,
        magnification: Int = 4,
        errorCorrection: ErrorCorrection = .medium
    ) {
        self.data = data
        self.position = position
        self.magnification = magnification
        self.errorCorrection = errorCorrection
    }
}
