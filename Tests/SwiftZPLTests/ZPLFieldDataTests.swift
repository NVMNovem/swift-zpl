//
//  ZPLFieldDataTests.swift
//  swift-zpl
//
//  Created by Damian Van de Kauter on 27/10/2026.
//

import Testing
@testable import SwiftZPL

/// What field data turns into, and that no text can turn into a command.
@Suite("Field data")
struct ZPLFieldDataTests {
    private let zd420 = ZPLEncoder(profile: .zebraZD420d203)
    private let generic = ZPLEncoder(profile: .generic)

    private func field(_ text: String, _ encoding: ZPLCharacterEncoding = .utf8, block: Bool = false) throws -> String {
        let text = ZPLText(text, at: .zero, height: 20, block: block ? ZPLText.Block(width: 100) : nil)
        let zpl = try zd420.zpl([.text(text)], encoding: encoding)
        let prefix = "^FO0,0^A0N,20,20" + (block ? "^FB100,1,0,L,0" : "")
        return String(zpl.dropFirst(prefix.count))
    }

    @Test("Plain ASCII is sent as written, without ^FH")
    func plainASCII() throws {
        #expect(try field("Product 1042, 50% off!") == "^FDProduct 1042, 50% off!^FS")
        #expect(try field("A_B") == "^FDA_B^FS")
    }

    @Test("Command prefixes are escaped, so text cannot end the field or start a command")
    func injection() throws {
        #expect(try field("^XZ^XA~JR") == "^FH_^FD_5EXZ_5EXA_7EJR^FS")
        #expect(try field("^FS^FO0,0^FDowned") == "^FH_^FD_5EFS_5EFO0,0_5EFDowned^FS")
        #expect(try field("A_B^") == "^FH_^FDA_5FB_5E^FS")
    }

    @Test("Dutch text in UTF-8")
    func dutchUTF8() throws {
        #expect(try field("café") == "^FH_^FDcaf_C3_A9^FS")
        #expect(try field("België") == "^FH_^FDBelgi_C3_AB^FS")
        #expect(try field("Prijs: €4,95") == "^FH_^FDPrijs: _E2_82_AC4,95^FS")
        #expect(try field("’s-Hertogenbosch") == "^FH_^FD_E2_80_99s-Hertogenbosch^FS")
    }

    @Test("Dutch text in code page 1252")
    func dutchWindows1252() throws {
        #expect(try field("café", .windows1252) == "^FH_^FDcaf_E9^FS")
        #expect(try field("België", .windows1252) == "^FH_^FDBelgi_EB^FS")
        #expect(try field("Prijs: €4,95", .windows1252) == "^FH_^FDPrijs: _804,95^FS")
        #expect(try field("’s-Hertogenbosch", .windows1252) == "^FH_^FD_92s-Hertogenbosch^FS")
        #expect(try field("ŒŸ", .windows1252) == "^FH_^FD_8C_9F^FS")
    }

    @Test("A letter with a combining accent encodes as its precomposed form")
    func decomposed() throws {
        #expect(try field("cafe\u{301}") == "^FH_^FDcaf_C3_A9^FS")
        #expect(try field("cafe\u{301}", .windows1252) == "^FH_^FDcaf_E9^FS")
    }

    @Test("Characters outside the set are refused, never replaced")
    func unencodable() {
        #expect(throws: ZPLEncodingError.unencodableCharacter("€", .usa1)) {
            try generic.encode(ZPLLabel([.text(ZPLText("€ 4,95", at: .zero))]))
        }
        #expect(throws: ZPLEncodingError.unencodableCharacter("é", .usa1)) {
            try generic.encode(ZPLLabel([.text(ZPLText("café", at: .zero))]))
        }
        #expect(throws: ZPLEncodingError.unencodableCharacter("😀", .windows1252)) {
            try zd420.encode(ZPLLabel([.text(ZPLText("😀", at: .zero))], characterEncoding: .windows1252))
        }
        #expect(throws: ZPLEncodingError.unencodableCharacter("ő", .windows1252)) {
            try zd420.encode(ZPLLabel([.text(ZPLText("ő", at: .zero))], characterEncoding: .windows1252))
        }
    }

    @Test("UTF-8 holds any character; whether the font draws it is the printer's")
    func utf8Anything() throws {
        #expect(try field("😀") == "^FH_^FD_F0_9F_98_80^FS")
    }

    @Test("A character set the profile does not list is refused")
    func unsupportedEncoding() {
        #expect(throws: ZPLEncodingError.unsupportedCharacterEncoding(.utf8)) {
            try generic.encode(ZPLLabel([], characterEncoding: .utf8))
        }
    }

    @Test("Control characters are refused")
    func controlCharacters() {
        for scalar: Unicode.Scalar in ["\t", "\u{0}", "\u{1B}", "\r", "\u{7F}", "\u{85}"] {
            #expect(throws: ZPLEncodingError.controlCharacter(scalar)) {
                try zd420.encode(ZPLLabel([.text(ZPLText("a\(Character(scalar))b", at: .zero))]))
            }
        }
    }

    @Test("Line breaks are refused outside a block and become \\& inside one")
    func lineBreaks() throws {
        #expect(throws: ZPLEncodingError.lineBreakNotAllowed) {
            try zd420.encode(ZPLLabel([.text(ZPLText("a\nb", at: .zero))]))
        }
        #expect(try field("a\nb", block: true) == #"^FDa\&b^FS"#)
    }

    @Test("A backslash is doubled inside a block, where ^FB reads escapes, and kept outside")
    func backslash() throws {
        #expect(try field(#"a\b"#) == #"^FDa\b^FS"#)
        #expect(try field(#"a\b"#, block: true) == #"^FDa\\b^FS"#)
        #expect(try field(#"a\&b"#, block: true) == #"^FDa\\&b^FS"#)
    }

    @Test("Field data longer than ^FD takes is refused")
    func length() throws {
        #expect(try field(String(repeating: "a", count: 3072)).count == 3072 + 6)
        #expect(throws: ZPLEncodingError.fieldDataTooLong(byteCount: 3073)) {
            try zd420.encode(ZPLLabel([.text(ZPLText(String(repeating: "a", count: 3073), at: .zero))]))
        }
        #expect(throws: ZPLEncodingError.fieldDataTooLong(byteCount: 3075)) {
            try zd420.encode(ZPLLabel([.text(ZPLText(String(repeating: "^", count: 1025), at: .zero))]))
        }
    }

    @Test("Every encoded byte is printable ASCII")
    func asciiOutput() throws {
        let label = ZPLLabel([
            .text(ZPLText("Crème ^ ~ _ € 😀 \\", at: .zero)),
            .qrCode(ZPLQRCode("a\nb€", at: .zero)),
        ])
        #expect(try zd420.encode(label).allSatisfy { (0x20...0x7E).contains($0) })
    }
}
