//
//  ZPLGraphic.swift
//  swift-zpl
//
//  Created by Damian Van de Kauter on 27/10/2026.
//

/// A raster image placed on the label, sent inline as an ASCII-hex graphic field (`^GFA`).
///
/// The image travels with every label that uses it. For a logo printed on thousands of labels,
/// storing it on the printer once is cheaper; that is not modelled yet.
public struct ZPLGraphic: Sendable, Hashable {
    public var image: ZPLRasterImage
    public var position: ZPLPosition

    public init(_ image: ZPLRasterImage, at position: ZPLPosition) {
        self.image = image
        self.position = position
    }
}
