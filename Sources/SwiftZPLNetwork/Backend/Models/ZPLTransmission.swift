//
//  ZPLTransmission.swift
//  swift-zpl
//
//  Created by Damian Van de Kauter on 27/10/2026.
//

/// A job that was handed over completely.
///
/// Every byte was accepted by the operating system and the connection closed cleanly. That is
/// all it says: it does not mean the printer parsed the ZPL, nor that a label came out. ZPL has
/// no per-job acknowledgement over raw TCP; ``ZPLConnection/status()`` is the most there is.
public struct ZPLTransmission: Sendable, Hashable {
    public let bytesSent: Int
    public let duration: Duration
}
