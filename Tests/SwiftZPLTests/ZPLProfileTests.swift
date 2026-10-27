//
//  ZPLProfileTests.swift
//  swift-zpl
//
//  Created by Damian Van de Kauter on 27/10/2026.
//

import Testing
@testable import SwiftZPL

@Suite("Profiles")
struct ZPLProfileTests {
    @Test("Built-in identifiers are stable, because they are persisted")
    func identifiers() {
        #expect(ZPLProfile.builtin.map(\.id) == [
            "generic-zpl", "zebra-zd420d-203dpi", "zebra-zd420d-300dpi", "zebra-zd420t-203dpi", "zebra-zd420t-300dpi",
        ])
        #expect(ZPLProfile.builtin(id: "zebra-zd420t-300dpi") == .zebraZD420t300)
        #expect(ZPLProfile.builtin(id: "unknown") == nil)
    }

    @Test("The ZD420 variants differ where the hardware does")
    func zd420Variants() {
        #expect(ZPLProfile.zebraZD420d203.resolution == .dpi203)
        #expect(ZPLProfile.zebraZD420d300.resolution == .dpi300)
        #expect(ZPLProfile.zebraZD420d203.maximumPrintWidth == 832)
        #expect(ZPLProfile.zebraZD420d300.maximumPrintWidth == 1228)
        #expect(ZPLProfile.zebraZD420d203.printSpeeds == 2...6)
        #expect(ZPLProfile.zebraZD420d300.printSpeeds == 2...4)
        #expect(!ZPLProfile.zebraZD420d203.capabilities.contains(.thermalTransfer))
        #expect(ZPLProfile.zebraZD420t203.capabilities.contains(.thermalTransfer))
    }

    @Test("Print width and length match the spec sheet's 104 × 991 mm at each resolution")
    func zd420Dimensions() {
        for profile in [ZPLProfile.zebraZD420d203, .zebraZD420d300, .zebraZD420t203, .zebraZD420t300] {
            #expect(ZPLLength.millimeters(104).dots(at: profile.resolution) == profile.maximumPrintWidth)
            #expect(ZPLLength.millimeters(991).dots(at: profile.resolution) == profile.maximumLabelLength)
        }
    }

    @Test("Optional hardware is never claimed by a built-in profile")
    func optionalHardware() {
        for profile in ZPLProfile.builtin {
            #expect(!profile.capabilities.contains(.cutter))
            #expect(!profile.capabilities.contains(.peeler))
            #expect(!profile.interfaces.standard.contains(.ethernet))
            #expect(!profile.interfaces.standard.contains(.wifi))
        }
        #expect(ZPLProfile.zebraZD420d203.interfaces.optional.isSuperset(of: [.ethernet, .wifi]))
    }

    @Test("Adding installed options keeps the model's identifier")
    func adding() {
        let withCutter = ZPLProfile.zebraZD420d203.adding(.cutter)
        #expect(withCutter.id == ZPLProfile.zebraZD420d203.id)
        #expect(withCutter.capabilities == ZPLProfile.zebraZD420d203.capabilities.union(.cutter))
    }

    @Test("No built-in profile claims a hardware test that has not happened")
    func verification() {
        #expect(ZPLProfile.generic.verification == .assumed)
        for profile in ZPLProfile.builtin where profile != .generic {
            #expect(profile.verification == .documented)
        }
    }

    @Test("The generic profile is conservative")
    func generic() {
        #expect(ZPLProfile.generic.capabilities.isEmpty)
        #expect(ZPLProfile.generic.characterEncodings == [.usa1])
    }
}
