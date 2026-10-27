//
//  ZPLEncoder+String.swift
//  swift-zpl
//
//  Created by Damian Van de Kauter on 27/10/2026.
//

@testable import SwiftZPL

extension ZPLEncoder {
    /// The encoded label as text; the encoder only ever produces printable ASCII.
    func zpl(_ label: ZPLLabel) throws(ZPLEncodingError) -> String {
        String(decoding: try encode(label), as: UTF8.self)
    }

    /// One label holding only these commands, without the `^XA^CI28` and `^XZ` around them.
    func zpl(_ commands: [ZPLCommand], encoding: ZPLCharacterEncoding? = nil) throws(ZPLEncodingError) -> String {
        let label = ZPLLabel(commands, characterEncoding: encoding)
        let zpl = try self.zpl(label)
        let header = "^XA^CI\((encoding ?? profile.defaultCharacterEncoding).characterSetNumber)"
        return String(zpl.dropFirst(header.count).dropLast(3))
    }
}
