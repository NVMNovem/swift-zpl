//
//  ZPLResolution.swift
//  swift-zpl
//
//  Created by Damian Van de Kauter on 27/10/2026.
//

/// The printhead's density: how many dots make up a millimetre.
///
/// ZPL addresses everything in dots, so the same label at two resolutions is two different command
/// streams. The raw value is the nominal dpi and may be persisted.
public enum ZPLResolution: Int, Sendable, Hashable, CaseIterable, Codable {
    /// Zebra's "203 dpi": exactly 8 dots/mm, so 203.2 dots per inch.
    case dpi203 = 203
    /// 300 dots per inch, about 11.81 dots/mm. Zebra's spec sheets round this to "12 dots/mm"; the
    /// conversion here uses the exact 300 / 25.4.
    case dpi300 = 300
    /// 600 dots per inch, about 23.62 dots/mm.
    case dpi600 = 600

    public var dotsPerMillimeter: Double {
        switch self {
        case .dpi203: 8
        case .dpi300: 300 / 25.4
        case .dpi600: 600 / 25.4
        }
    }

    public var dotsPerInch: Double {
        switch self {
        case .dpi203: 203.2
        case .dpi300: 300
        case .dpi600: 600
        }
    }
}
