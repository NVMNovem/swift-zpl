//
//  ZPLEncoderTests.swift
//  swift-zpl
//
//  Created by Damian Van de Kauter on 27/10/2026.
//

import Testing
@testable import SwiftZPL

/// Golden output: every expected string is written out from the ZPL II Programming Guide.
@Suite("ZPL encoder")
struct ZPLEncoderTests {
    private let zd420 = ZPLEncoder(profile: .zebraZD420d203)
    private let zd420at300 = ZPLEncoder(profile: .zebraZD420d300)
    private let generic = ZPLEncoder(profile: .generic)

    // MARK: - Labels

    @Test("An empty label is a format with only its character set")
    func emptyLabel() throws {
        #expect(try zd420.zpl(ZPLLabel([])) == "^XA^CI28^XZ")
        #expect(try generic.zpl(ZPLLabel([])) == "^XA^CI0^XZ")
        #expect(try zd420.zpl(ZPLLabel([], characterEncoding: .windows1252)) == "^XA^CI27^XZ")
    }

    @Test("A basic text label")
    func basicText() throws {
        let label = ZPLLabel([.text(ZPLText("Product 1042", at: ZPLPosition(x: 40, y: 40)))])
        #expect(try zd420.zpl(label) == "^XA^CI28^FO40,40^A0N,30,30^FDProduct 1042^FS^XZ")
    }

    @Test("Several fields keep their order")
    func multipleFields() throws {
        let label = ZPLLabel([
            .text(ZPLText("Top", at: ZPLPosition(x: 10, y: 10), height: 20)),
            .box(.horizontalLine(at: ZPLPosition(x: 10, y: 40), length: 300, thickness: 2)),
            .text(ZPLText("Bottom", at: ZPLPosition(x: 10, y: 50), height: 20)),
        ])
        #expect(
            try zd420.zpl(label)
                == "^XA^CI28^FO10,10^A0N,20,20^FDTop^FS^FO10,40^GB300,2,2,B,0^FS^FO10,50^A0N,20,20^FDBottom^FS^XZ"
        )
    }

    @Test("Labels encoded together follow one another")
    func multipleLabels() throws {
        let first = ZPLLabel([.text(ZPLText("1", at: .zero))])
        let second = ZPLLabel([.text(ZPLText("2", at: .zero))], quantity: 2)
        let bytes = try zd420.encode([first, second])
        #expect(
            String(decoding: bytes, as: UTF8.self)
                == "^XA^CI28^FO0,0^A0N,30,30^FD1^FS^XZ^XA^CI28^FO0,0^A0N,30,30^FD2^FS^PQ2^XZ"
        )
    }

    @Test("Print quantity is sent before the end of the format, and only when above one")
    func quantity() throws {
        #expect(try zd420.zpl(ZPLLabel([], quantity: 1)) == "^XA^CI28^XZ")
        #expect(try zd420.zpl(ZPLLabel([], quantity: 3)) == "^XA^CI28^PQ3^XZ")
        #expect(throws: ZPLEncodingError.outOfRange(.quantity, value: 0, allowed: 1...99_999_999)) {
            try zd420.encode(ZPLLabel([], quantity: 0))
        }
    }

    // MARK: - Setup

    @Test("Setup commands encode to their documented form")
    func setupCommands() throws {
        let cases: [(ZPLCommand, String)] = [
            (.printWidth(832), "^PW832"),
            (.labelLength(480), "^LL480"),
            (.labelHome(ZPLPosition(x: 12, y: 8)), "^LH12,8"),
            (.printOrientation(.normal), "^PON"),
            (.printOrientation(.inverted), "^POI"),
            (.mediaTracking(.continuous), "^MNN"),
            (.mediaTracking(.gap), "^MNY"),
            (.mediaTracking(.mark), "^MNM"),
            (.mediaType(.directThermal), "^MTD"),
            (.printMode(.tearOff), "^MMT"),
            (.printSpeed(inchesPerSecond: 2), "^PR2"),
            (.printSpeed(inchesPerSecond: 6), "^PR6"),
            (.darkness(0), "~SD00"),
            (.darkness(5), "~SD05"),
            (.darkness(30), "~SD30"),
        ]
        for (command, expected) in cases {
            #expect(try zd420.zpl([command]) == expected, "\(command)")
        }
    }

    @Test("Label dimensions in millimetres follow the profile's resolution")
    func dimensions() throws {
        let setup: [ZPLCommand] = [.printWidth(.millimeters(104)), .labelLength(.millimeters(60))]
        #expect(try zd420.zpl(setup) == "^PW832^LL480")
        #expect(try zd420at300.zpl(setup) == "^PW1228^LL709")
    }

    @Test("Setup values outside the profile are refused")
    func setupLimits() {
        #expect(throws: ZPLEncodingError.outOfRange(.printWidth, value: 840, allowed: 2...832)) {
            try zd420.encode(ZPLLabel([.printWidth(.millimeters(105))]))
        }
        #expect(throws: ZPLEncodingError.outOfRange(.labelLength, value: 0, allowed: 1...7928)) {
            try zd420.encode(ZPLLabel([.labelLength(0)]))
        }
        #expect(throws: ZPLEncodingError.outOfRange(.printSpeed, value: 6, allowed: 2...4)) {
            try zd420at300.encode(ZPLLabel([.printSpeed(inchesPerSecond: 6)]))
        }
        #expect(throws: ZPLEncodingError.outOfRange(.darkness, value: 31, allowed: 0...30)) {
            try zd420.encode(ZPLLabel([.darkness(31)]))
        }
    }

    @Test("Hardware-dependent media settings need the capability")
    func mediaCapabilities() throws {
        #expect(throws: ZPLEncodingError.unsupported(missing: .thermalTransfer)) {
            try zd420.encode(ZPLLabel([.mediaType(.thermalTransfer)]))
        }
        #expect(try ZPLEncoder(profile: .zebraZD420t203).zpl([.mediaType(.thermalTransfer)]) == "^MTT")

        #expect(throws: ZPLEncodingError.unsupported(missing: .cutter)) {
            try zd420.encode(ZPLLabel([.printMode(.cutter)]))
        }
        #expect(throws: ZPLEncodingError.unsupported(missing: .peeler)) {
            try zd420.encode(ZPLLabel([.printMode(.peelOff)]))
        }
        let withOptions = ZPLEncoder(profile: ZPLProfile.zebraZD420d203.adding([.cutter, .peeler]))
        #expect(try withOptions.zpl([.printMode(.cutter)]) == "^MMC")
        #expect(try withOptions.zpl([.printMode(.peelOff)]) == "^MMP")
    }

    // MARK: - Coordinates

    @Test("Positions in millimetres and inches convert with the profile's resolution")
    func coordinates() throws {
        let millimeters = ZPLText("A", at: ZPLPosition(x: .millimeters(10), y: .millimeters(15)), height: 20)
        #expect(try zd420.zpl([.text(millimeters)]) == "^FO80,120^A0N,20,20^FDA^FS")
        #expect(try zd420at300.zpl([.text(millimeters)]) == "^FO118,177^A0N,20,20^FDA^FS")

        let inches = ZPLText("A", at: ZPLPosition(x: .inches(1), y: .inches(0.5)), height: 20)
        #expect(try zd420.zpl([.text(inches)]) == "^FO203,102^A0N,20,20^FDA^FS")
        #expect(try zd420at300.zpl([.text(inches)]) == "^FO300,150^A0N,20,20^FDA^FS")
    }

    @Test("A field must start within the printhead")
    func coordinateLimits() {
        #expect(throws: ZPLEncodingError.outOfRange(.x, value: 832, allowed: 0...831)) {
            try zd420.encode(ZPLLabel([.text(ZPLText("A", at: ZPLPosition(x: 832, y: 0)))]))
        }
        #expect(throws: ZPLEncodingError.outOfRange(.y, value: -1, allowed: 0...32000)) {
            try zd420.encode(ZPLLabel([.text(ZPLText("A", at: ZPLPosition(x: 0, y: -1)))]))
        }
        #expect(throws: ZPLEncodingError.invalidLength(.x, .millimeters(.infinity))) {
            try zd420.encode(ZPLLabel([.text(ZPLText("A", at: ZPLPosition(x: .millimeters(.infinity), y: 0)))]))
        }
    }

    // MARK: - Text

    @Test("Font, size and orientation are written out in full")
    func textAttributes() throws {
        let text = ZPLText(
            "A", at: .zero, font: try #require(ZPLFont("D")), height: 36, width: 20, orientation: .rotated
        )
        #expect(try zd420.zpl([.text(text)]) == "^FO0,0^ADR,36,20^FDA^FS")
        #expect(throws: ZPLEncodingError.outOfRange(.fontHeight, value: 0, allowed: 1...32000)) {
            try zd420.encode(ZPLLabel([.text(ZPLText("A", at: .zero, height: 0))]))
        }
    }

    @Test("Font names are a single upper-case letter or digit")
    func fontNames() {
        #expect(ZPLFont("A") != nil)
        #expect(ZPLFont("9") != nil)
        #expect(ZPLFont("a") == nil)
        #expect(ZPLFont("^") == nil)
        #expect(ZPLFont("é") == nil)
    }

    @Test("A text block wraps, aligns and keeps line breaks")
    func textBlock() throws {
        let block = ZPLText.Block(width: 400, maximumLines: 2, lineSpacing: 4, alignment: .center)
        let text = ZPLText("Line 1\nLine 2", at: ZPLPosition(x: 10, y: 20), height: 25, block: block)
        #expect(try zd420.zpl([.text(text)]) == #"^FO10,20^A0N,25,25^FB400,2,4,C,0^FDLine 1\&Line 2^FS"#)

        let windows = ZPLText("A\r\nB", at: .zero, height: 25, block: block)
        #expect(try zd420.zpl([.text(windows)]) == #"^FO0,0^A0N,25,25^FB400,2,4,C,0^FDA\&B^FS"#)

        let invalid = ZPLText.Block(width: 400, maximumLines: 0)
        #expect(throws: ZPLEncodingError.outOfRange(.maximumLines, value: 0, allowed: 1...9999)) {
            try zd420.encode(ZPLLabel([.text(ZPLText("A", at: .zero, block: invalid))]))
        }
    }

    // MARK: - Barcodes

    @Test("Code 128")
    func code128() throws {
        let position = ZPLPosition(x: 40, y: 120)
        #expect(
            try zd420.zpl([.barcode(.code128("1042", at: position, height: 80))])
                == "^FO40,120^BY2^BCN,80,Y,N,N,A^FD1042^FS"
        )
        #expect(
            try zd420.zpl([.barcode(.code128("1042", at: position, height: 80, moduleWidth: 3, interpretation: .none))])
                == "^FO40,120^BY3^BCN,80,N,N,N,A^FD1042^FS"
        )
        #expect(
            try zd420.zpl([.barcode(.code128("1042", at: position, height: 80, orientation: .rotated, interpretation: .above))])
                == "^FO40,120^BY2^BCR,80,Y,Y,N,A^FD1042^FS"
        )
    }

    @Test("Code 128 data that collides with ZPL is escaped or refused")
    func code128Data() throws {
        #expect(
            try zd420.zpl([.barcode(.code128("A^B_C", at: .zero, height: 50))])
                == "^FO0,0^BY2^BCN,50,Y,N,N,A^FH_^FDA_5EB_5FC^FS"
        )
        #expect(throws: ZPLEncodingError.invalidBarcodeData(.code128, .invalidCharacter(">"))) {
            try zd420.encode(ZPLLabel([.barcode(.code128("A>B", at: .zero, height: 50))]))
        }
        #expect(throws: ZPLEncodingError.invalidBarcodeData(.code128, .invalidCharacter("é"))) {
            try zd420.encode(ZPLLabel([.barcode(.code128("café", at: .zero, height: 50))]))
        }
        #expect(throws: ZPLEncodingError.invalidBarcodeData(.code128, .empty)) {
            try zd420.encode(ZPLLabel([.barcode(.code128("", at: .zero, height: 50))]))
        }
    }

    @Test("Code 39")
    func code39() throws {
        let barcode = ZPLBarcode.code39(
            "ABC-123", at: .zero, height: 50, checkDigit: true, moduleWidth: 3, wideBarRatio: 2.5
        )
        #expect(try zd420.zpl([.barcode(barcode)]) == "^FO0,0^BY3,2.5^B3N,Y,50,Y,N^FDABC-123^FS")
        #expect(
            try zd420.zpl([.barcode(.code39("A B$/+%.", at: .zero, height: 50))])
                == "^FO0,0^BY2,3.0^B3N,N,50,Y,N^FDA B$/+%.^FS"
        )

        #expect(throws: ZPLEncodingError.invalidBarcodeData(.code39(checkDigit: false), .invalidCharacter("a"))) {
            try zd420.encode(ZPLLabel([.barcode(.code39("abc", at: .zero, height: 50))]))
        }
        #expect(throws: ZPLEncodingError.invalidBarcodeData(.code39(checkDigit: false), .invalidCharacter("*"))) {
            try zd420.encode(ZPLLabel([.barcode(.code39("*A*", at: .zero, height: 50))]))
        }
        #expect(throws: ZPLEncodingError.outOfRange(.wideBarRatio, value: 35, allowed: 20...30)) {
            try zd420.encode(ZPLLabel([.barcode(.code39("A", at: .zero, height: 50, wideBarRatio: 3.5))]))
        }
    }

    @Test("EAN-13 takes twelve digits, or thirteen with a correct check digit")
    func ean13() throws {
        let expected = "^FO0,0^BY2^BEN,60,Y,N^FD590123412345^FS"
        #expect(try zd420.zpl([.barcode(.ean13("590123412345", at: .zero, height: 60))]) == expected)
        #expect(try zd420.zpl([.barcode(.ean13("5901234123457", at: .zero, height: 60))]) == expected)

        #expect(throws: ZPLEncodingError.invalidBarcodeData(.ean13, .invalidCheckDigit(expected: "7"))) {
            try zd420.encode(ZPLLabel([.barcode(.ean13("5901234123458", at: .zero, height: 60))]))
        }
        #expect(throws: ZPLEncodingError.invalidBarcodeData(.ean13, .invalidLength(5))) {
            try zd420.encode(ZPLLabel([.barcode(.ean13("12345", at: .zero, height: 60))]))
        }
        #expect(throws: ZPLEncodingError.invalidBarcodeData(.ean13, .invalidCharacter("a"))) {
            try zd420.encode(ZPLLabel([.barcode(.ean13("12345678901a", at: .zero, height: 60))]))
        }
    }

    @Test("The EAN-13 check digit")
    func ean13CheckDigit() {
        #expect(ZPLEncoder.ean13CheckDigit(Array("590123412345".utf8)) == UInt8(ascii: "7"))
        #expect(ZPLEncoder.ean13CheckDigit(Array("400638133393".utf8)) == UInt8(ascii: "1"))
        #expect(ZPLEncoder.ean13CheckDigit(Array("000000000000".utf8)) == UInt8(ascii: "0"))
    }

    @Test("Barcode sizes outside the command's range are refused")
    func barcodeLimits() {
        #expect(throws: ZPLEncodingError.outOfRange(.moduleWidth, value: 11, allowed: 1...10)) {
            try zd420.encode(ZPLLabel([.barcode(.code128("1", at: .zero, height: 50, moduleWidth: 11))]))
        }
        #expect(throws: ZPLEncodingError.outOfRange(.barcodeHeight, value: 0, allowed: 1...32000)) {
            try zd420.encode(ZPLLabel([.barcode(.code128("1", at: .zero, height: 0))]))
        }
    }

    // MARK: - QR codes

    @Test("QR codes")
    func qrCode() throws {
        let code = ZPLQRCode("https://example.com/p/1042", at: ZPLPosition(x: 40, y: 40), magnification: 5)
        #expect(try zd420.zpl([.qrCode(code)]) == "^FO40,40^BQN,2,5^FDMA,https://example.com/p/1042^FS")

        let high = ZPLQRCode("1042", at: .zero, errorCorrection: .high)
        #expect(try zd420.zpl([.qrCode(high)]) == "^FO0,0^BQN,2,4^FDHA,1042^FS")
    }

    @Test("QR data keeps line breaks and is escaped like any field data")
    func qrCodeData() throws {
        #expect(try zd420.zpl([.qrCode(ZPLQRCode("a\nb", at: .zero))]) == "^FO0,0^BQN,2,4^FH_^FDMA,a_0Ab^FS")
        #expect(try zd420.zpl([.qrCode(ZPLQRCode("€", at: .zero))]) == "^FO0,0^BQN,2,4^FH_^FDMA,_E2_82_AC^FS")
    }

    @Test("QR codes are refused when too large, empty or unsupported")
    func qrCodeLimits() {
        #expect(throws: ZPLEncodingError.unsupported(missing: .qrCodes)) {
            try generic.encode(ZPLLabel([.qrCode(ZPLQRCode("1", at: .zero))]))
        }
        let tooLarge = ZPLQRCode(String(repeating: "a", count: 1274), at: .zero, errorCorrection: .high)
        #expect(throws: ZPLEncodingError.qrDataTooLarge(byteCount: 1274, maximum: 1273)) {
            try zd420.encode(ZPLLabel([.qrCode(tooLarge)]))
        }
        #expect(throws: ZPLEncodingError.qrDataTooLarge(byteCount: 0, maximum: 0)) {
            try zd420.encode(ZPLLabel([.qrCode(ZPLQRCode("", at: .zero))]))
        }
        #expect(throws: ZPLEncodingError.outOfRange(.magnification, value: 11, allowed: 1...10)) {
            try zd420.encode(ZPLLabel([.qrCode(ZPLQRCode("1", at: .zero, magnification: 11))]))
        }
        // 2000 bytes fit the symbol, but escaped they no longer fit `^FD`.
        let escapedTooLong = ZPLQRCode(String(repeating: "é", count: 1000), at: .zero)
        #expect(throws: ZPLEncodingError.fieldDataTooLong(byteCount: 6003)) {
            try zd420.encode(ZPLLabel([.qrCode(escapedTooLong)]))
        }
    }

    // MARK: - Graphics

    @Test("Boxes and lines")
    func boxes() throws {
        let box = ZPLBox(at: ZPLPosition(x: 10, y: 10), width: 200, height: 100, thickness: 3)
        #expect(try zd420.zpl([.box(box)]) == "^FO10,10^GB200,100,3,B,0^FS")
        let rounded = ZPLBox(at: .zero, width: 50, height: 50, thickness: 50, color: .white, cornerRounding: 8)
        #expect(try zd420.zpl([.box(rounded)]) == "^FO0,0^GB50,50,50,W,8^FS")
        #expect(try zd420.zpl([.box(.verticalLine(at: .zero, length: 120, thickness: 4))]) == "^FO0,0^GB4,120,4,B,0^FS")

        #expect(throws: ZPLEncodingError.outOfRange(.boxWidth, value: 2, allowed: 3...32000)) {
            try zd420.encode(ZPLLabel([.box(ZPLBox(at: .zero, width: 2, height: 10, thickness: 3))]))
        }
        #expect(throws: ZPLEncodingError.outOfRange(.cornerRounding, value: 9, allowed: 0...8)) {
            try zd420.encode(ZPLLabel([.box(ZPLBox(at: .zero, width: 10, height: 10, cornerRounding: 9))]))
        }
    }

    @Test("Raster images become an ASCII-hex graphic field")
    func graphic() throws {
        let image = ZPLRasterImage(width: 10, height: 2) { x, y in x == 0 || y == 1 }
        #expect(image.packedRows == [0x80, 0x00, 0xFF, 0xC0])
        #expect(try zd420.zpl([.graphic(ZPLGraphic(image, at: .zero))]) == "^FO0,0^GFA,4,4,2,8000FFC0^FS")
        #expect(throws: ZPLEncodingError.unsupported(missing: .graphicFields)) {
            try generic.encode(ZPLLabel([.graphic(ZPLGraphic(image, at: .zero))]))
        }
        #expect(ZPLRasterImage(width: 10, height: 2, packedRows: [0x00]) == nil)
    }

    // MARK: - Resolutions

    @Test("The same label differs between resolutions")
    func resolutions() throws {
        let label = ZPLLabel([
            .text(ZPLText("A", at: ZPLPosition(x: .millimeters(5), y: .millimeters(5)), height: .millimeters(4))),
        ])
        #expect(try zd420.zpl(label) == "^XA^CI28^FO40,40^A0N,32,32^FDA^FS^XZ")
        #expect(try zd420at300.zpl(label) == "^XA^CI28^FO59,59^A0N,47,47^FDA^FS^XZ")
    }

    // MARK: - Raw

    @Test("Raw ZPL passes unchanged when it cannot break the label around it")
    func rawAccepted() throws {
        #expect(try zd420.zpl([.raw("^FO10,10^GC50,2,B^FS")]) == "^FO10,10^GC50,2,B^FS")
        #expect(try zd420.zpl([.raw("~TA000")]) == "~TA000")
    }

    @Test("Raw ZPL that would break the label is refused")
    func rawRefused() {
        let cases: [(String, ZPLEncodingError.RawProblem)] = [
            ("", .empty),
            ("FO10,10", .missingPrefix),
            ("^FO1,1\n", .invalidCharacter("\n")),
            ("^FDé^FS", .invalidCharacter("é")),
            ("^XZ", .forbiddenCommand("^XZ")),
            ("^FS^XA", .forbiddenCommand("^XA")),
            ("~cc^", .forbiddenCommand("~CC")),
            ("^CT~", .forbiddenCommand("^CT")),
            ("^FDabc", .unterminatedField),
            ("^FDa^FS^FVb", .unterminatedField),
        ]
        for (zpl, problem) in cases {
            #expect(throws: ZPLEncodingError.invalidRawCommand(zpl, problem), "\(zpl)") {
                try zd420.encode(ZPLLabel([.raw(zpl)]))
            }
        }
    }

    // MARK: - A realistic label

    /// A 100 × 60 mm product label at 203 dpi, as in the README.
    @Test("A complete product label")
    func productLabel() throws {
        let label = ZPLLabel([
            .printWidth(.millimeters(100)),
            .labelLength(.millimeters(60)),
            .mediaTracking(.gap),
            .box(ZPLBox(at: ZPLPosition(x: .millimeters(2), y: .millimeters(2)),
                        width: .millimeters(96), height: .millimeters(56), thickness: 3)),
            .text(ZPLText("Crème brûlée", at: ZPLPosition(x: .millimeters(5), y: .millimeters(5)),
                          height: .millimeters(6))),
            .text(ZPLText("Art. 1042 · 4 × 90 g", at: ZPLPosition(x: .millimeters(5), y: .millimeters(13)),
                          height: .millimeters(3.5))),
            .text(ZPLText("€ 4,95", at: ZPLPosition(x: .millimeters(60), y: .millimeters(5)), height: .millimeters(8),
                          block: ZPLText.Block(width: .millimeters(35), alignment: .right))),
            .barcode(.ean13("5901234123457", at: ZPLPosition(x: .millimeters(5), y: .millimeters(22)),
                            height: .millimeters(15))),
            .qrCode(ZPLQRCode("https://example.com/p/1042", at: ZPLPosition(x: .millimeters(70), y: .millimeters(22)),
                              magnification: 4)),
        ], quantity: 2)

        #expect(try zd420.zpl(label) == """
            ^XA^CI28^PW800^LL480^MNY\
            ^FO16,16^GB768,448,3,B,0^FS\
            ^FO40,40^A0N,48,48^FH_^FDCr_C3_A8me br_C3_BBl_C3_A9e^FS\
            ^FO40,104^A0N,28,28^FH_^FDArt. 1042 _C2_B7 4 _C3_97 90 g^FS\
            ^FO480,40^A0N,64,64^FB280,1,0,R,0^FH_^FD_E2_82_AC 4,95^FS\
            ^FO40,176^BY2^BEN,120,Y,N^FD590123412345^FS\
            ^FO560,176^BQN,2,4^FDMA,https://example.com/p/1042^FS\
            ^PQ2^XZ
            """)
    }
}
