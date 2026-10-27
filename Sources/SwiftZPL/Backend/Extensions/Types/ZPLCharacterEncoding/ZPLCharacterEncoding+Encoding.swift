//
//  ZPLCharacterEncoding+Encoding.swift
//  swift-zpl
//
//  Created by Damian Van de Kauter on 27/10/2026.
//

extension ZPLCharacterEncoding {
    /// The bytes one character is written as, or `nil` when the set cannot hold it.
    ///
    /// Control characters are not handled here; field data refuses them before asking. A letter
    /// written with a combining accent (`e` + U+0301) is treated as its precomposed form (`é`)
    /// whenever Latin-1 or code page 1252 has one, so text from any source encodes the same way.
    func bytes(for character: Character) -> [UInt8]? {
        if let ascii = character.asciiValue {
            return (0x20...0x7E).contains(ascii) ? [ascii] : nil
        }
        switch self {
        case .usa1:
            return nil
        case .windows1252:
            return Self.windows1252Bytes[character].map { [$0] }
        case .utf8:
            if let scalar = Self.precomposedScalars[character] {
                return Array(String(Character(scalar)).utf8)
            }
            return Array(String(character).utf8)
        }
    }

    // MARK: - Tables

    /// 0x80–0x9F of code page 1252 as Unicode scalars; `nil` where the byte is undefined.
    /// 0xA0–0xFF are Latin-1, the same numbers as their scalars.
    static let windows1252ControlRange: [UInt32?] = [
        0x20AC, nil, 0x201A, 0x0192, 0x201E, 0x2026, 0x2020, 0x2021,
        0x02C6, 0x2030, 0x0160, 0x2039, 0x0152, nil, 0x017D, nil,
        nil, 0x2018, 0x2019, 0x201C, 0x201D, 0x2022, 0x2013, 0x2014,
        0x02DC, 0x2122, 0x0161, 0x203A, 0x0153, nil, 0x017E, 0x0178,
    ]

    /// Every non-ASCII character of code page 1252 and its byte. Keyed by `Character`, whose
    /// equality is canonical equivalence, so decomposed input finds its precomposed entry.
    private static let windows1252Bytes: [Character: UInt8] = {
        var table: [Character: UInt8] = [:]
        for (offset, value) in windows1252ControlRange.enumerated() {
            guard let value, let scalar = Unicode.Scalar(value) else { continue }
            table[Character(scalar)] = UInt8(0x80 + offset)
        }
        for value in UInt32(0xA0)...0xFF {
            table[Character(Unicode.Scalar(value)!)] = UInt8(value)
        }
        return table
    }()

    /// The same characters, to their single precomposed scalar.
    private static let precomposedScalars: [Character: Unicode.Scalar] = {
        var table: [Character: Unicode.Scalar] = [:]
        for character in windows1252Bytes.keys {
            table[character] = character.unicodeScalars.first!
        }
        return table
    }()
}
