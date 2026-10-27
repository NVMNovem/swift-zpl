//
//  ZPLHostStatusTests.swift
//  swift-zpl
//
//  Created by Damian Van de Kauter on 27/10/2026.
//

import Testing
@testable import SwiftZPL

/// Answers built from the `~HS` layout in the ZPL II Programming Guide.
@Suite("Host status")
struct ZPLHostStatusTests {
    static func response(
        _ first: String = "030,0,0,0480,000,0,0,0,000,0,0,0",
        second: String = "001,0,0,0,1,2,6,0,00000000,1,000",
        third: String = "1234,0"
    ) -> [UInt8] {
        [first, second, third].flatMap { [0x02] + Array($0.utf8) + [0x03, 0x0D, 0x0A] }
    }

    @Test("A printer with nothing to report is ready and idle")
    func ready() throws {
        let status = try ZPLHostStatus(response: Self.response())
        #expect(status.isReady)
        #expect(status.isIdle)
        #expect(status.labelLength == 480)
        #expect(status.isThermalTransferMode)
        #expect(status.printMode == .tearOff)
        #expect(status == ZPLHostStatus(labelLength: 480, isThermalTransferMode: true, printMode: .tearOff))
    }

    @Test("Paper out and pause block printing")
    func paperOutAndPaused() throws {
        let status = try ZPLHostStatus(response: Self.response("030,1,1,0480,000,0,0,0,000,0,0,0"))
        #expect(status.isPaperOut)
        #expect(status.isPaused)
        #expect(!status.isReady)
    }

    @Test("An open head blocks printing")
    func headUp() throws {
        let status = try ZPLHostStatus(response: Self.response(second: "001,0,1,0,0,2,6,0,00000000,1,000"))
        #expect(status.isHeadUp)
        #expect(!status.isReady)
    }

    @Test("The ribbon only counts in thermal-transfer mode")
    func ribbon() throws {
        let directThermal = try ZPLHostStatus(response: Self.response(second: "000,0,0,1,0,2,6,0,00000000,1,000"))
        #expect(directThermal.isRibbonOut)
        #expect(directThermal.isReady)

        let thermalTransfer = try ZPLHostStatus(response: Self.response(second: "001,0,0,1,1,2,6,0,00000000,1,000"))
        #expect(!thermalTransfer.isReady)
    }

    @Test("Temperature, buffer and configuration faults block printing")
    func faults() throws {
        #expect(!(try ZPLHostStatus(response: Self.response("030,0,0,0480,000,1,0,0,000,0,0,0"))).isReady)
        #expect(!(try ZPLHostStatus(response: Self.response("030,0,0,0480,000,0,0,0,000,1,0,0"))).isReady)
        #expect(!(try ZPLHostStatus(response: Self.response("030,0,0,0480,000,0,0,0,000,0,1,0"))).isReady)
        #expect(!(try ZPLHostStatus(response: Self.response("030,0,0,0480,000,0,0,0,000,0,0,1"))).isReady)
    }

    @Test("Work in the buffer or the batch is not idle")
    func busy() throws {
        let queued = try ZPLHostStatus(response: Self.response("030,0,0,0480,002,0,0,0,000,0,0,0"))
        #expect(queued.formatsInReceiveBuffer == 2)
        #expect(queued.isReady)
        #expect(!queued.isIdle)

        let printing = try ZPLHostStatus(response: Self.response(second: "001,0,0,0,1,2,6,0,00000005,1,000"))
        #expect(printing.labelsRemainingInBatch == 5)
        #expect(!printing.isIdle)

        let partial = try ZPLHostStatus(response: Self.response("030,0,0,0480,000,0,0,1,000,0,0,0"))
        #expect(!partial.isIdle)

        let waiting = try ZPLHostStatus(response: Self.response(second: "001,0,0,0,1,1,6,1,00000000,1,000"))
        #expect(waiting.printMode == .peelOff)
        #expect(waiting.isLabelWaiting)
        #expect(!waiting.isIdle)
    }

    @Test("Print modes", arguments: [
        ("0", ZPLHostStatus.PrintMode.rewind), ("3", .cutter), ("8", .partialCutter), ("K", .kiosk), ("Z", .other("Z")),
    ])
    func printModes(code: String, mode: ZPLHostStatus.PrintMode) throws {
        let status = try ZPLHostStatus(response: Self.response(second: "001,0,0,0,1,\(code),6,0,00000000,1,000"))
        #expect(status.printMode == mode)
    }

    @Test("Extra fields from newer firmware are accepted")
    func extraFields() throws {
        let status = try ZPLHostStatus(response: Self.response("030,0,0,0480,000,0,0,0,000,0,0,0,9", third: "1234,0,7"))
        #expect(status.isReady)
    }

    @Test("Malformed answers are refused, not misread")
    func malformed() {
        #expect(throws: ZPLStatusError.incompleteLine) {
            try ZPLHostStatus(response: Self.response() + [0x02, 0x31])
        }
        #expect(throws: ZPLStatusError.wrongLineCount(2)) {
            try ZPLHostStatus(response: Array(Self.response().dropLast(10)))
        }
        #expect(throws: ZPLStatusError.wrongLineCount(0)) {
            try ZPLHostStatus(response: [])
        }
        #expect(throws: ZPLStatusError.missingFields(line: 1, count: 3)) {
            try ZPLHostStatus(response: Self.response("030,0,0"))
        }
        #expect(throws: ZPLStatusError.invalidField(line: 1, index: 1, value: "x")) {
            try ZPLHostStatus(response: Self.response("030,x,0,0480,000,0,0,0,000,0,0,0"))
        }
        #expect(throws: ZPLStatusError.invalidField(line: 2, index: 8, value: "-1")) {
            try ZPLHostStatus(response: Self.response(second: "001,0,0,0,1,2,6,0,-1,1,000"))
        }
    }

    @Test("The request is ~HS")
    func request() {
        #expect(ZPLHostStatus.request == [0x7E, 0x48, 0x53])
    }
}
