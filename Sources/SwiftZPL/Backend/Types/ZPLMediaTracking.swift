//
//  ZPLMediaTracking.swift
//  swift-zpl
//
//  Created by Damian Van de Kauter on 27/10/2026.
//

/// How the printer finds the start of each label (`^MN`).
public enum ZPLMediaTracking: Character, Sendable, Hashable, CaseIterable {
    /// `N` — continuous media; the label length comes from `^LL`.
    case continuous = "N"
    /// `Y` — labels separated by gaps or notches, found with the transmissive sensor.
    case gap = "Y"
    /// `M` — a black mark on the back, found with the reflective sensor.
    case mark = "M"
}
