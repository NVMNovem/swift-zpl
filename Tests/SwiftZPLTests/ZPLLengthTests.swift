//
//  ZPLLengthTests.swift
//  swift-zpl
//
//  Created by Damian Van de Kauter on 27/10/2026.
//

import Testing
@testable import SwiftZPL

@Suite("Units")
struct ZPLLengthTests {
    @Test("Dots are dots at every resolution")
    func dots() {
        for resolution in ZPLResolution.allCases {
            #expect(ZPLLength.dots(42).dots(at: resolution) == 42)
        }
        let literal: ZPLLength = 7
        #expect(literal == .dots(7))
    }

    @Test("Millimetres convert with the resolution")
    func millimeters() {
        #expect(ZPLLength.millimeters(10).dots(at: .dpi203) == 80)
        #expect(ZPLLength.millimeters(10).dots(at: .dpi300) == 118)
        #expect(ZPLLength.millimeters(10).dots(at: .dpi600) == 236)
        #expect(ZPLLength.millimeters(25.4).dots(at: .dpi300) == 300)
        #expect(ZPLLength.millimeters(104).dots(at: .dpi203) == 832)
    }

    @Test("Inches convert with the resolution; 203 dpi is 8 dots/mm")
    func inches() {
        #expect(ZPLLength.inches(1).dots(at: .dpi203) == 203)
        #expect(ZPLLength.inches(4).dots(at: .dpi203) == 813)
        #expect(ZPLLength.inches(1).dots(at: .dpi300) == 300)
        #expect(ZPLLength.inches(1).dots(at: .dpi600) == 600)
    }

    @Test("Rounding is to the nearest dot, halves away from zero")
    func rounding() {
        #expect(ZPLLength.millimeters(0.0625).dots(at: .dpi203) == 1)
        #expect(ZPLLength.millimeters(0.06).dots(at: .dpi203) == 0)
        #expect(ZPLLength.millimeters(-0.0625).dots(at: .dpi203) == -1)
        #expect(ZPLLength.millimeters(0.1875).dots(at: .dpi203) == 2)
    }

    @Test("Lengths that are not numbers have no dots")
    func nonFinite() {
        #expect(ZPLLength.millimeters(.nan).dots(at: .dpi203) == nil)
        #expect(ZPLLength.inches(.infinity).dots(at: .dpi300) == nil)
        #expect(ZPLLength.millimeters(1e300).dots(at: .dpi203) == nil)
    }
}
