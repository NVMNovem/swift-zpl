//
//  ZPLPrintOrientation.swift
//  swift-zpl
//
//  Created by Damian Van de Kauter on 27/10/2026.
//

/// Whether the whole label is printed upside down (`^PO`).
public enum ZPLPrintOrientation: Character, Sendable, Hashable, CaseIterable {
    case normal = "N"
    case inverted = "I"
}
