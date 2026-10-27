//
//  ZPLCapabilities.swift
//  swift-zpl
//
//  Created by Damian Van de Kauter on 27/10/2026.
//

/// What a printer does beyond what every ZPL II printer is assumed to understand.
///
/// The baseline is label setup, text in resident fonts, Code 128, Code 39, EAN-13 and boxes.
/// Everything here must be listed in a profile before the encoder will emit it.
public struct ZPLCapabilities: OptionSet, Sendable, Hashable {
    public let rawValue: UInt32

    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    /// `^BQ` QR codes, model 2.
    public static let qrCodes = ZPLCapabilities(rawValue: 1 << 0)
    /// `^GF` graphic fields (raster images).
    public static let graphicFields = ZPLCapabilities(rawValue: 1 << 1)
    /// `~HS` host status over the connection the job is sent on.
    public static let hostStatus = ZPLCapabilities(rawValue: 1 << 2)
    /// A ribbon, so `^MTT` can be selected. Direct-thermal-only models lack it.
    public static let thermalTransfer = ZPLCapabilities(rawValue: 1 << 3)
    /// An installed cutter, so `^MMC` can be selected.
    public static let cutter = ZPLCapabilities(rawValue: 1 << 4)
    /// An installed dispenser, so `^MMP` can be selected.
    public static let peeler = ZPLCapabilities(rawValue: 1 << 5)
}
