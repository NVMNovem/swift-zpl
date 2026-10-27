//
//  ZPLFieldData.swift
//  swift-zpl
//
//  Created by Damian Van de Kauter on 27/10/2026.
//

/// Field data ready to sit between `^FD` and `^FS`.
///
/// This is where text stops being able to become ZPL. Every byte except printable ASCII other
/// than `^` and `~` is written as a `^FH` hex escape (`_5E` for `^`), and once escapes are in use
/// the indicator `_` itself is escaped too. The printer decodes the escapes after it has parsed the
/// field, so no field data, whoever wrote it, ends the field or starts a command.
struct ZPLFieldData {
    /// What a line break in the data means.
    enum LineBreaks {
        /// Refused.
        case refused
        /// A field block's line break, `\&`. A backslash is written `\\`, which `^FB` reads as one.
        case fieldBlock
        /// A line feed byte, for symbols that store it, such as QR codes.
        case lineFeed
    }

    /// The maximum `^FD` length, in bytes as sent.
    static let maximumLength = 3072

    /// The data as the character set writes it, before escaping.
    let bytes: [UInt8]

    init(
        _ text: String,
        encoding: ZPLCharacterEncoding,
        lineBreaks: LineBreaks
    ) throws(ZPLEncodingError) {
        var bytes: [UInt8] = []
        bytes.reserveCapacity(text.utf8.count)
        for character in text {
            if character == "\n" || character == "\r\n" {
                switch lineBreaks {
                case .refused: throw .lineBreakNotAllowed
                case .fieldBlock: bytes += [0x5C, 0x26]
                case .lineFeed: bytes.append(0x0A)
                }
                continue
            }
            if let control = character.unicodeScalars.first(where: Self.isControl) {
                throw .controlCharacter(control)
            }
            if lineBreaks == .fieldBlock, character == "\\" {
                bytes += [0x5C, 0x5C]
                continue
            }
            guard let encoded = encoding.bytes(for: character) else {
                throw .unencodableCharacter(character, encoding)
            }
            bytes += encoded
        }
        self.bytes = bytes
    }

    /// Wraps bytes that are already in the character set, such as validated barcode data.
    init(bytes: [UInt8]) {
        self.bytes = bytes
    }

    /// Whether the data needs `^FH`.
    var needsEscaping: Bool {
        bytes.contains { !Self.isLiteral($0) }
    }

    /// The data as sent: escaped when it needs to be.
    var escaped: [UInt8] {
        guard needsEscaping else { return bytes }
        var escaped: [UInt8] = []
        escaped.reserveCapacity(bytes.count * 2)
        for byte in bytes {
            if Self.isLiteral(byte), byte != Self.hexIndicator {
                escaped.append(byte)
            } else {
                escaped += [Self.hexIndicator, Self.hexDigit(byte >> 4), Self.hexDigit(byte & 0x0F)]
            }
        }
        return escaped
    }

    // MARK: - Bytes

    static let hexIndicator: UInt8 = 0x5F

    /// Printable ASCII other than the command prefixes `^` and `~`.
    private static func isLiteral(_ byte: UInt8) -> Bool {
        (0x20...0x7E).contains(byte) && byte != 0x5E && byte != 0x7E
    }

    private static func isControl(_ scalar: Unicode.Scalar) -> Bool {
        scalar.value < 0x20 || (0x7F...0x9F).contains(scalar.value)
    }

    static func hexDigit(_ nibble: UInt8) -> UInt8 {
        nibble < 10 ? 0x30 + nibble : 0x41 + nibble - 10
    }
}
