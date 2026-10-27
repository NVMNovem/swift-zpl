//
//  ZPLStatusError.swift
//  swift-zpl
//
//  Created by Damian Van de Kauter on 27/10/2026.
//

/// A `~HS` answer that does not have the documented shape, refused rather than misread.
public enum ZPLStatusError: Error, Sendable, Hashable {
    /// An `STX` without its `ETX`.
    case incompleteLine
    /// Not the three `STX … ETX` lines.
    case wrongLineCount(Int)
    /// A line, numbered from 1, with fewer fields than documented.
    case missingFields(line: Int, count: Int)
    /// A field, numbered from 0, that is not the documented flag or number.
    case invalidField(line: Int, index: Int, value: String)
}
