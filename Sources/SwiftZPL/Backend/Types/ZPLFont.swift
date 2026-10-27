//
//  ZPLFont.swift
//  swift-zpl
//
//  Created by Damian Van de Kauter on 27/10/2026.
//

/// A font resident on the printer, named by the single letter or digit `^A` takes.
///
/// Which names exist, and which characters each can draw, is the printer's: the encoder checks the
/// name's shape, not that the font is installed.
public struct ZPLFont: Sendable, Hashable {
    public let name: Character

    /// A font by its name, `A`–`Z` or `0`–`9`; `nil` for anything else.
    public init?(_ name: Character) {
        guard name.isASCII, name.isUppercase || name.isNumber else { return nil }
        self.name = name
    }

    private init(unchecked name: Character) {
        self.name = name
    }

    /// Font `0`, the scalable CG Triumvirate Bold Condensed. The usual choice on Zebra printers.
    public static let scalable = ZPLFont(unchecked: "0")
}
