//
//  ZPLInterface.swift
//  swift-zpl
//
//  Created by Damian Van de Kauter on 27/10/2026.
//

/// A way a printer can be connected. Informational: only ``ethernet`` and ``wifi`` reach the raw
/// TCP port that `SwiftZPLNetwork` talks to.
public enum ZPLInterface: String, Sendable, Hashable, CaseIterable, Codable {
    case usb
    /// A USB port for keyboards, scanners and memory sticks, not for printing from a host.
    case usbHost
    case bluetoothLowEnergy
    case bluetoothClassic
    case ethernet
    case wifi
    case serial
}
