//
//  ZPLTextAlignment.swift
//  swift-zpl
//
//  Created by Damian Van de Kauter on 27/10/2026.
//

/// How the lines of a text block sit within its width (`^FB`).
public enum ZPLTextAlignment: Character, Sendable, Hashable, CaseIterable {
    case left = "L"
    case center = "C"
    case right = "R"
    /// Stretched to both edges; the last line is left-aligned.
    case justified = "J"
}
