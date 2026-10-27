//
//  ZPLEncodingError.swift
//  swift-zpl
//
//  Created by Damian Van de Kauter on 27/10/2026.
//

/// Why a label could not be encoded for a profile.
public enum ZPLEncodingError: Error, Sendable, Hashable {
    /// A numeric parameter the error is about.
    public enum Parameter: Sendable, Hashable {
        case x
        case y
        case printWidth
        case labelLength
        case printSpeed
        case darkness
        case quantity
        case fontHeight
        case fontWidth
        case blockWidth
        case maximumLines
        case lineSpacing
        case hangingIndent
        case barcodeHeight
        case moduleWidth
        case wideBarRatio
        case magnification
        case boxWidth
        case boxHeight
        case thickness
        case cornerRounding
    }

    /// What is wrong with barcode data.
    public enum BarcodeProblem: Sendable, Hashable {
        case empty
        /// The symbology cannot encode the character, or ZPL reserves it.
        case invalidCharacter(Character)
        case invalidLength(Int)
        /// An EAN-13 with thirteen digits whose last is not the check digit of the first twelve.
        case invalidCheckDigit(expected: Character)
    }

    /// What is wrong with a ``ZPLCommand/raw(_:)`` command.
    public enum RawProblem: Sendable, Hashable {
        case empty
        /// It does not start with `^` or `~`.
        case missingPrefix
        /// A character outside printable ASCII, line breaks included.
        case invalidCharacter(Character)
        /// A command the encoder must control itself, such as `^XZ`.
        case forbiddenCommand(String)
        /// `^FD` or `^FV` without a `^FS` after it.
        case unterminatedField
    }

    /// The profile does not list the capability the command needs.
    case unsupported(missing: ZPLCapabilities)
    /// The profile does not list the character set.
    case unsupportedCharacterEncoding(ZPLCharacterEncoding)
    /// The character set cannot hold the character.
    case unencodableCharacter(Character, ZPLCharacterEncoding)
    /// Field data holds a control character, such as a tab, that has no meaning on a label.
    case controlCharacter(Unicode.Scalar)
    /// A line break in field data that cannot hold one: text outside a ``ZPLText/Block`` or
    /// barcode data.
    case lineBreakNotAllowed
    /// A value outside what the command, or the profile, allows. For lengths the value is in dots.
    case outOfRange(Parameter, value: Int, allowed: ClosedRange<Int>)
    /// A length that is not a finite number, or too large to count in dots.
    case invalidLength(Parameter, ZPLLength)
    /// A ratio that is not a finite number.
    case invalidRatio(Double)
    case invalidBarcodeData(ZPLBarcode.Symbology, BarcodeProblem)
    /// The QR data, in bytes, exceeds what the error correction level allows.
    case qrDataTooLarge(byteCount: Int, maximum: Int)
    /// Escaped field data is longer than the 3072 bytes `^FD` takes.
    case fieldDataTooLong(byteCount: Int)
    case invalidRawCommand(String, RawProblem)
}
