//
//  ZPLText.swift
//  swift-zpl
//
//  Created by Damian Van de Kauter on 27/10/2026.
//

/// A text field in a resident font.
///
/// The content is field data, never ZPL: `^`, `~` and anything outside printable ASCII is sent as a
/// hex escape, so no text can end the field or start a command. A line break is only allowed in a
/// ``Block``, where it becomes the block's own line break (`\&`).
public struct ZPLText: Sendable, Hashable {
    /// A field block (`^FB`): a fixed width the text wraps and aligns in.
    public struct Block: Sendable, Hashable {
        public var width: ZPLLength
        /// Lines before the printer stops; text beyond the last line overprints it. 1…9999.
        public var maximumLines: Int
        /// Extra space between lines, -9999…9999 dots.
        public var lineSpacing: ZPLLength
        public var alignment: ZPLTextAlignment
        /// Indent of every line after the first, 0…9999 dots.
        public var hangingIndent: ZPLLength

        public init(
            width: ZPLLength,
            maximumLines: Int = 1,
            lineSpacing: ZPLLength = 0,
            alignment: ZPLTextAlignment = .left,
            hangingIndent: ZPLLength = 0
        ) {
            self.width = width
            self.maximumLines = maximumLines
            self.lineSpacing = lineSpacing
            self.alignment = alignment
            self.hangingIndent = hangingIndent
        }
    }

    public var content: String
    public var position: ZPLPosition
    public var font: ZPLFont
    /// Character height, 1…32000 dots. A bitmap font is scaled by whole factors, so the printer
    /// rounds this to the nearest multiple of the font's own height.
    public var height: ZPLLength
    /// Character width; `nil` sends the height, which for the scalable font keeps its proportions.
    public var width: ZPLLength?
    public var orientation: ZPLOrientation
    public var block: Block?

    public init(
        _ content: String,
        at position: ZPLPosition,
        font: ZPLFont = .scalable,
        height: ZPLLength = 30,
        width: ZPLLength? = nil,
        orientation: ZPLOrientation = .normal,
        block: Block? = nil
    ) {
        self.content = content
        self.position = position
        self.font = font
        self.height = height
        self.width = width
        self.orientation = orientation
        self.block = block
    }
}
