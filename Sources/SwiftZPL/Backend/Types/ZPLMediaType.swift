//
//  ZPLMediaType.swift
//  swift-zpl
//
//  Created by Damian Van de Kauter on 27/10/2026.
//

/// Whether the printer burns into heat-sensitive media or through a ribbon (`^MT`).
public enum ZPLMediaType: Character, Sendable, Hashable, CaseIterable {
    /// `D`
    case directThermal = "D"
    /// `T` — needs ``ZPLCapabilities/thermalTransfer``.
    case thermalTransfer = "T"
}
