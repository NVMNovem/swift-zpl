//
//  ZPLPrintMode.swift
//  swift-zpl
//
//  Created by Damian Van de Kauter on 27/10/2026.
//

/// What happens to a label once printed (`^MM`).
public enum ZPLPrintMode: Character, Sendable, Hashable, CaseIterable {
    /// `T` — fed to the tear bar.
    case tearOff = "T"
    /// `P` — peeled from the liner and presented; needs ``ZPLCapabilities/peeler``.
    case peelOff = "P"
    /// `C` — cut; needs ``ZPLCapabilities/cutter``.
    case cutter = "C"
}
