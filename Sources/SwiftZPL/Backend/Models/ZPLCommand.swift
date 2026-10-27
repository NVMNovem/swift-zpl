//
//  ZPLCommand.swift
//  swift-zpl
//
//  Created by Damian Van de Kauter on 27/10/2026.
//

/// One instruction inside a label format, as a value.
///
/// Commands are collected in a ``ZPLLabel``, which supplies the `^XA … ^XZ` around them, and turned
/// into bytes by ``ZPLEncoder``, which checks each against the printer's ``ZPLProfile``.
///
/// The setup commands change the printer's current settings, not only this label's: `^PW`, `^LL`,
/// `^MN`, `^MT`, `^MM`, `^PR` and `~SD` stay in effect for later labels until changed again or the
/// printer restarts. None of them is saved across a restart; this library never sends `^JUS`.
public enum ZPLCommand: Sendable, Hashable {
    /// `^LH x,y` — moves the origin every later position is measured from.
    case labelHome(ZPLPosition)
    /// `^PW` — the printable width, at most the profile's ``ZPLProfile/maximumPrintWidth``.
    case printWidth(ZPLLength)
    /// `^LL` — the label length, at most the profile's ``ZPLProfile/maximumLabelLength``.
    case labelLength(ZPLLength)
    /// `^PO`
    case printOrientation(ZPLPrintOrientation)
    /// `^MN`
    case mediaTracking(ZPLMediaTracking)
    /// `^MT`
    case mediaType(ZPLMediaType)
    /// `^MM`
    case printMode(ZPLPrintMode)
    /// `^PR` — print speed in inches per second, within the profile's ``ZPLProfile/printSpeeds``.
    case printSpeed(inchesPerSecond: Int)
    /// `~SD` — darkness, 0…30. A tilde command: the printer applies it as soon as it arrives.
    case darkness(Int)
    /// `^FO … ^A … ^FD … ^FS`
    case text(ZPLText)
    /// `^FO … ^BY … ^BC`/`^B3`/`^BE … ^FD … ^FS`
    case barcode(ZPLBarcode)
    /// `^FO … ^BQ … ^FD … ^FS`; needs ``ZPLCapabilities/qrCodes``.
    case qrCode(ZPLQRCode)
    /// `^FO … ^GB … ^FS` — boxes and lines.
    case box(ZPLBox)
    /// `^FO … ^GFA … ^FS`; needs ``ZPLCapabilities/graphicFields``.
    case graphic(ZPLGraphic)
    /// ZPL sent as written, for what this library does not model.
    ///
    /// The escape hatch is checked only for what would break the label around it: it must be
    /// printable ASCII starting with `^` or `~`, must not start or end a format (`^XA`, `^XZ`),
    /// change the command prefix or delimiter (`^CC`, `^CD`, `^CT` and their `~` forms), or leave a
    /// field open (`^FD`/`^FV` without a following `^FS`). Everything else — including commands that
    /// reset the printer or save settings permanently — is the caller's responsibility, and field
    /// data in it is not escaped. Never build it from text a user typed.
    case raw(String)
}
