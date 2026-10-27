//
//  ZPLCharacterEncoding.swift
//  swift-zpl
//
//  Created by Damian Van de Kauter on 27/10/2026.
//

/// The character set field data is written in, selected with `^CI` at the top of every label.
///
/// The encoder always sends `^CI`, so a label never depends on what another program left selected.
/// Every byte outside printable ASCII is sent as a `^FH` hex escape, so the command stream itself
/// stays ASCII whichever set is chosen. A character the set cannot hold fails encoding with
/// ``ZPLEncodingError/unencodableCharacter(_:_:)``; nothing is replaced silently.
///
/// Holding a character is not drawing it: whether a glyph exists is the font's business, and the
/// printer prints nothing, or a box, for one it lacks. The encoder cannot see that.
///
/// The raw value is a stable identifier and may be persisted.
public enum ZPLCharacterEncoding: String, Sendable, Hashable, CaseIterable, Codable {
    /// `^CI0`. Treated as printable ASCII only: the upper half of the printer's table and its
    /// national substitutions are not modelled, so `é` and `€` are refused.
    case usa1
    /// `^CI27`, Zebra code page 1252: Windows Latin 1, with `€` at 0x80. Holds every letter of
    /// Dutch, French and German.
    case windows1252
    /// `^CI28`, Unicode as UTF-8. Needs Link-OS or comparable recent firmware.
    case utf8

    /// The number `^CI` takes.
    public var characterSetNumber: Int {
        switch self {
        case .usa1: 0
        case .windows1252: 27
        case .utf8: 28
        }
    }
}
