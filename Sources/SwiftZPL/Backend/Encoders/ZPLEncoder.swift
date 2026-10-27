//
//  ZPLEncoder.swift
//  swift-zpl
//
//  Created by Damian Van de Kauter on 27/10/2026.
//

/// Turns labels into the ZPL one printer model understands.
///
/// The encoder is strict: a command the ``ZPLProfile`` does not list, a value outside its range
/// or a character the label's set cannot hold is refused, never sent in the hope that it works.
/// Deciding what to do instead is the caller's job, using the profile.
///
/// Output is deterministic — the same label and profile give the same bytes — and always printable
/// ASCII. Parameters are written out in full rather than left to the printer's defaults, so a
/// label does not depend on what the previous one set.
public struct ZPLEncoder: Sendable {
    public let profile: ZPLProfile

    public init(profile: ZPLProfile) {
        self.profile = profile
    }

    /// Encodes one label.
    public func encode(_ label: ZPLLabel) throws(ZPLEncodingError) -> [UInt8] {
        var output = Output()
        try encode(label, into: &output)
        return output.bytes
    }

    /// Encodes labels one after the other, as one job.
    public func encode(_ labels: [ZPLLabel]) throws(ZPLEncodingError) -> [UInt8] {
        var output = Output()
        for label in labels {
            try encode(label, into: &output)
        }
        return output.bytes
    }

    // MARK: - Labels

    private func encode(_ label: ZPLLabel, into output: inout Output) throws(ZPLEncodingError) {
        let encoding = label.characterEncoding ?? profile.defaultCharacterEncoding
        guard profile.supports(encoding) else { throw .unsupportedCharacterEncoding(encoding) }
        try check(label.quantity, .quantity, in: 1...99_999_999)

        output.append("^XA^CI\(encoding.characterSetNumber)")
        for command in label.commands {
            try encode(command, encoding: encoding, into: &output)
        }
        if label.quantity != 1 {
            output.append("^PQ\(label.quantity)")
        }
        output.append("^XZ")
    }

    // MARK: - Commands

    private func encode(
        _ command: ZPLCommand,
        encoding: ZPLCharacterEncoding,
        into output: inout Output
    ) throws(ZPLEncodingError) {
        switch command {
        case .labelHome(let position):
            let (x, y) = try coordinates(position, maximumX: Self.maximumCoordinate)
            output.append("^LH\(x),\(y)")

        case .printWidth(let width):
            output.append("^PW\(try dots(width, .printWidth, in: 2...profile.maximumPrintWidth))")

        case .labelLength(let length):
            output.append("^LL\(try dots(length, .labelLength, in: 1...profile.maximumLabelLength))")

        case .printOrientation(let orientation):
            output.append("^PO\(orientation.rawValue)")

        case .mediaTracking(let tracking):
            output.append("^MN\(tracking.rawValue)")

        case .mediaType(let type):
            if type == .thermalTransfer { try require(.thermalTransfer) }
            output.append("^MT\(type.rawValue)")

        case .printMode(let mode):
            switch mode {
            case .tearOff: break
            case .peelOff: try require(.peeler)
            case .cutter: try require(.cutter)
            }
            output.append("^MM\(mode.rawValue)")

        case .printSpeed(let speed):
            try check(speed, .printSpeed, in: profile.printSpeeds)
            output.append("^PR\(speed)")

        case .darkness(let darkness):
            try check(darkness, .darkness, in: 0...30)
            output.append("~SD\(darkness < 10 ? "0" : "")\(darkness)")

        case .text(let text):
            try encodeText(text, encoding: encoding, into: &output)

        case .barcode(let barcode):
            try encodeBarcode(barcode, encoding: encoding, into: &output)

        case .qrCode(let code):
            try require(.qrCodes)
            try encodeQRCode(code, encoding: encoding, into: &output)

        case .box(let box):
            try encodeBox(box, into: &output)

        case .graphic(let graphic):
            try require(.graphicFields)
            try encodeGraphic(graphic, into: &output)

        case .raw(let zpl):
            try Self.validateRaw(zpl)
            output.append(zpl)
        }
    }

    private func require(_ capability: ZPLCapabilities) throws(ZPLEncodingError) {
        guard profile.capabilities.contains(capability) else {
            throw .unsupported(missing: capability)
        }
    }

    // MARK: - Text

    private func encodeText(
        _ text: ZPLText,
        encoding: ZPLCharacterEncoding,
        into output: inout Output
    ) throws(ZPLEncodingError) {
        let (x, y) = try coordinates(text.position)
        let height = try dots(text.height, .fontHeight, in: 1...Self.maximumCoordinate)
        var width = height
        if let explicitWidth = text.width {
            width = try dots(explicitWidth, .fontWidth, in: 1...Self.maximumCoordinate)
        }

        output.append("^FO\(x),\(y)^A\(text.font.name)\(text.orientation.rawValue),\(height),\(width)")
        if let block = text.block {
            let blockWidth = try dots(block.width, .blockWidth, in: 1...Self.maximumCoordinate)
            try check(block.maximumLines, .maximumLines, in: 1...9999)
            let spacing = try dots(block.lineSpacing, .lineSpacing, in: -9999...9999)
            let indent = try dots(block.hangingIndent, .hangingIndent, in: 0...9999)
            output.append(
                "^FB\(blockWidth),\(block.maximumLines),\(spacing),\(block.alignment.rawValue),\(indent)"
            )
        }
        let data = try ZPLFieldData(
            text.content, encoding: encoding, lineBreaks: text.block == nil ? .refused : .fieldBlock
        )
        try output.appendField(data)
    }

    // MARK: - Barcodes

    private func encodeBarcode(
        _ barcode: ZPLBarcode,
        encoding: ZPLCharacterEncoding,
        into output: inout Output
    ) throws(ZPLEncodingError) {
        let (x, y) = try coordinates(barcode.position)
        let height = try dots(barcode.height, .barcodeHeight, in: 1...Self.maximumCoordinate)
        try check(barcode.moduleWidth, .moduleWidth, in: 1...10)
        let o = barcode.orientation.rawValue
        let line = barcode.interpretation == .none ? "N" : "Y"
        let above = barcode.interpretation == .above ? "Y" : "N"

        output.append("^FO\(x),\(y)")
        switch barcode.symbology {
        case .code128:
            let data = try Self.validateCode128(barcode.data)
            output.append("^BY\(barcode.moduleWidth)^BC\(o),\(height),\(line),\(above),N,A")
            try output.appendField(ZPLFieldData(bytes: data))

        case .code39(let checkDigit):
            let data = try Self.validateCode39(barcode.data, symbology: barcode.symbology)
            guard barcode.wideBarRatio.isFinite else { throw .invalidRatio(barcode.wideBarRatio) }
            let tenths = Int((barcode.wideBarRatio * 10).rounded(.toNearestOrAwayFromZero))
            try check(tenths, .wideBarRatio, in: 20...30)
            output.append("^BY\(barcode.moduleWidth),\(tenths / 10).\(tenths % 10)")
            output.append("^B3\(o),\(checkDigit ? "Y" : "N"),\(height),\(line),\(above)")
            try output.appendField(ZPLFieldData(bytes: data))

        case .ean13:
            let data = try Self.validateEAN13(barcode.data)
            output.append("^BY\(barcode.moduleWidth)^BE\(o),\(height),\(line),\(above)")
            try output.appendField(ZPLFieldData(bytes: data))
        }
    }

    /// Printable ASCII except `>`, which starts a subset invocation code in `^BC` data.
    private static func validateCode128(_ data: String) throws(ZPLEncodingError) -> [UInt8] {
        guard !data.isEmpty else { throw .invalidBarcodeData(.code128, .empty) }
        var bytes: [UInt8] = []
        for character in data {
            guard let ascii = character.asciiValue, (0x20...0x7E).contains(ascii), ascii != 0x3E else {
                throw .invalidBarcodeData(.code128, .invalidCharacter(character))
            }
            bytes.append(ascii)
        }
        return bytes
    }

    private static let code39Characters = Set("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ -.$/+%")

    private static func validateCode39(
        _ data: String,
        symbology: ZPLBarcode.Symbology
    ) throws(ZPLEncodingError) -> [UInt8] {
        guard !data.isEmpty else { throw .invalidBarcodeData(symbology, .empty) }
        if let invalid = data.first(where: { !code39Characters.contains($0) }) {
            throw .invalidBarcodeData(symbology, .invalidCharacter(invalid))
        }
        return Array(data.utf8)
    }

    /// Twelve digits as sent; a thirteenth must be their check digit and is left for the printer
    /// to compute again.
    private static func validateEAN13(_ data: String) throws(ZPLEncodingError) -> [UInt8] {
        guard !data.isEmpty else { throw .invalidBarcodeData(.ean13, .empty) }
        if let invalid = data.first(where: { !$0.isASCII || !$0.isNumber }) {
            throw .invalidBarcodeData(.ean13, .invalidCharacter(invalid))
        }
        let digits = Array(data.utf8)
        guard digits.count == 12 || digits.count == 13 else {
            throw .invalidBarcodeData(.ean13, .invalidLength(digits.count))
        }
        let payload = Array(digits.prefix(12))
        if digits.count == 13 {
            let expected = ean13CheckDigit(payload)
            guard digits[12] == expected else {
                throw .invalidBarcodeData(.ean13, .invalidCheckDigit(expected: Character(Unicode.Scalar(expected))))
            }
        }
        return payload
    }

    /// Weights 1 and 3 alternating from the left over twelve digits.
    static func ean13CheckDigit(_ digits: [UInt8]) -> UInt8 {
        var sum = 0
        for (index, digit) in digits.enumerated() {
            sum += Int(digit - 0x30) * (index.isMultiple(of: 2) ? 1 : 3)
        }
        return UInt8(0x30 + (10 - sum % 10) % 10)
    }

    // MARK: - QR code

    /// `^BQN,2,m` — model 2 — and `^FD` with the error correction and `A` for automatic input mode.
    private func encodeQRCode(
        _ code: ZPLQRCode,
        encoding: ZPLCharacterEncoding,
        into output: inout Output
    ) throws(ZPLEncodingError) {
        let (x, y) = try coordinates(code.position)
        try check(code.magnification, .magnification, in: 1...10)
        let data = try ZPLFieldData(code.data, encoding: encoding, lineBreaks: .lineFeed)
        guard !data.bytes.isEmpty else { throw .qrDataTooLarge(byteCount: 0, maximum: 0) }
        let maximum = code.errorCorrection.maximumByteCount
        guard data.bytes.count <= maximum else {
            throw .qrDataTooLarge(byteCount: data.bytes.count, maximum: maximum)
        }
        output.append("^FO\(x),\(y)^BQN,2,\(code.magnification)")
        try output.appendField(data, prefix: "\(code.errorCorrection.rawValue)A,")
    }

    // MARK: - Graphics

    private func encodeBox(_ box: ZPLBox, into output: inout Output) throws(ZPLEncodingError) {
        let (x, y) = try coordinates(box.position)
        let thickness = try dots(box.thickness, .thickness, in: 1...Self.maximumCoordinate)
        let width = try dots(box.width, .boxWidth, in: thickness...Self.maximumCoordinate)
        let height = try dots(box.height, .boxHeight, in: thickness...Self.maximumCoordinate)
        try check(box.cornerRounding, .cornerRounding, in: 0...8)
        output.append(
            "^FO\(x),\(y)^GB\(width),\(height),\(thickness),\(box.color.rawValue),\(box.cornerRounding)^FS"
        )
    }

    /// `^GFA,b,c,d,data`: total bytes, total bytes again, bytes per row, the rows in hex.
    private func encodeGraphic(_ graphic: ZPLGraphic, into output: inout Output) throws(ZPLEncodingError) {
        let (x, y) = try coordinates(graphic.position)
        let image = graphic.image
        output.append(
            "^FO\(x),\(y)^GFA,\(image.packedRows.count),\(image.packedRows.count),\(image.bytesPerRow),"
        )
        output.bytes.reserveCapacity(output.bytes.count + image.packedRows.count * 2 + 3)
        for byte in image.packedRows {
            output.bytes += [ZPLFieldData.hexDigit(byte >> 4), ZPLFieldData.hexDigit(byte & 0x0F)]
        }
        output.append("^FS")
    }

    // MARK: - Raw

    private static let forbiddenRawCommands: Set<String> = ["XA", "XZ", "CC", "CD", "CT"]

    /// Splits the command the way the printer does — at every `^` and `~` — and checks the pieces.
    private static func validateRaw(_ zpl: String) throws(ZPLEncodingError) {
        guard let first = zpl.first else { throw .invalidRawCommand(zpl, .empty) }
        guard first == "^" || first == "~" else { throw .invalidRawCommand(zpl, .missingPrefix) }
        if let invalid = zpl.first(where: { !($0.asciiValue.map { (0x20...0x7E).contains($0) } ?? false) }) {
            throw .invalidRawCommand(zpl, .invalidCharacter(invalid))
        }
        let bytes = Array(zpl.utf8)
        var isFieldOpen = false
        for (index, byte) in bytes.enumerated() where byte == 0x5E || byte == 0x7E {
            let name = String(decoding: bytes[(index + 1)..<min(index + 3, bytes.count)], as: UTF8.self)
                .uppercased()
            if forbiddenRawCommands.contains(name) {
                throw .invalidRawCommand(zpl, .forbiddenCommand(String(UnicodeScalar(byte)) + name))
            }
            switch name {
            case "FD", "FV": isFieldOpen = true
            case "FS": isFieldOpen = false
            default: break
            }
        }
        guard !isFieldOpen else { throw .invalidRawCommand(zpl, .unterminatedField) }
    }

    // MARK: - Values

    /// The largest coordinate or size ZPL takes.
    static let maximumCoordinate = 32000

    /// A field origin: `x` must fall within the printhead, `y` within what ZPL addresses.
    private func coordinates(
        _ position: ZPLPosition,
        maximumX: Int? = nil
    ) throws(ZPLEncodingError) -> (Int, Int) {
        let x = try dots(position.x, .x, in: 0...(maximumX ?? (profile.maximumPrintWidth - 1)))
        let y = try dots(position.y, .y, in: 0...Self.maximumCoordinate)
        return (x, y)
    }

    private func dots(
        _ length: ZPLLength,
        _ parameter: ZPLEncodingError.Parameter,
        in allowed: ClosedRange<Int>
    ) throws(ZPLEncodingError) -> Int {
        guard let dots = length.dots(at: profile.resolution) else {
            throw .invalidLength(parameter, length)
        }
        try check(dots, parameter, in: allowed)
        return dots
    }

    private func check(
        _ value: Int,
        _ parameter: ZPLEncodingError.Parameter,
        in allowed: ClosedRange<Int>
    ) throws(ZPLEncodingError) {
        guard allowed.contains(value) else {
            throw .outOfRange(parameter, value: value, allowed: allowed)
        }
    }
}

// MARK: - Output

extension ZPLEncoder {
    struct Output {
        var bytes: [UInt8] = []

        mutating func append(_ zpl: String) {
            bytes += zpl.utf8
        }

        /// `^FH_` when the data needs escapes, then `^FD`, the prefix, the data and `^FS`.
        mutating func appendField(_ data: ZPLFieldData, prefix: String = "") throws(ZPLEncodingError) {
            let escaped = data.escaped
            let length = prefix.utf8.count + escaped.count
            guard length <= ZPLFieldData.maximumLength else { throw .fieldDataTooLong(byteCount: length) }
            if data.needsEscaping {
                append("^FH_")
            }
            append("^FD")
            append(prefix)
            bytes += escaped
            append("^FS")
        }
    }
}
