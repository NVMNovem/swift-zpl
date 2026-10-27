//
//  ZPLLabel.swift
//  swift-zpl
//
//  Created by Damian Van de Kauter on 27/10/2026.
//

/// One label format: `^XA`, the character set, the commands, the quantity, `^XZ`.
///
/// A label is the unit ZPL works in, so it is the unit this library encodes. Starting and ending
/// the format are not commands; a label cannot be left open.
public struct ZPLLabel: Sendable, Hashable {
    public var commands: [ZPLCommand]
    /// `^PQ` — how many copies to print, 1…99 999 999.
    public var quantity: Int
    /// The `^CI` set for this label's field data; `nil` uses the profile's
    /// ``ZPLProfile/defaultCharacterEncoding``.
    public var characterEncoding: ZPLCharacterEncoding?

    public init(
        _ commands: [ZPLCommand],
        quantity: Int = 1,
        characterEncoding: ZPLCharacterEncoding? = nil
    ) {
        self.commands = commands
        self.quantity = quantity
        self.characterEncoding = characterEncoding
    }
}
