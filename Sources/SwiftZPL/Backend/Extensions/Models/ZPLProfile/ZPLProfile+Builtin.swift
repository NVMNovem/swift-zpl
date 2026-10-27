//
//  ZPLProfile+Builtin.swift
//  swift-zpl
//
//  Created by Damian Van de Kauter on 27/10/2026.
//

extension ZPLProfile {
    /// Every built-in profile, for looking one up by its persisted ``id``.
    public static let builtin: [ZPLProfile] = [
        .generic, .zebraZD420d203, .zebraZD420d300, .zebraZD420t203, .zebraZD420t300,
    ]

    /// The built-in profile with this identifier.
    public static func builtin(id: String) -> ZPLProfile? {
        builtin.first { $0.id == id }
    }

    /// A deliberately conservative subset for an unknown printer that claims ZPL II, such as
    /// another vendor's emulation.
    ///
    /// 203 dpi, four inches wide, ASCII only. Setup, text, linear barcodes and boxes; no QR codes,
    /// graphics or status, whose support in emulations varies too much to assume.
    public static let generic = ZPLProfile(
        id: "generic-zpl",
        name: "Generic ZPL II",
        resolution: .dpi203,
        capabilities: [],
        characterEncodings: [.usa1],
        defaultCharacterEncoding: .usa1,
        maximumPrintWidth: 832,
        maximumLabelLength: 7928,
        printSpeeds: 2...4,
        interfaces: Interfaces(standard: [], optional: [.ethernet]),
        verification: .assumed
    )

    // MARK: - Zebra ZD420

    // From Zebra's ZD420 technical specifications (2016) and the ZPL II Programming Guide; none of
    // it is yet tested on a printer in this project.
    //
    // - Print width 4.09 in (104 mm) at both resolutions: 832 dots at 203 dpi, 1228 at 300 dpi.
    // - Print length up to 39 in (991 mm): 7928 dots at 203 dpi, 11705 at 300 dpi.
    // - Speed 2–6 in/s at 203 dpi, 2–4 in/s at 300 dpi.
    // - Standard USB 2.0, USB host and Bluetooth Low Energy. Ethernet 10/100 and RS-232 serial are
    //   field-installable; Wi-Fi 802.11ac with Bluetooth 4.1 is factory-installed. Raw TCP needs
    //   one of the network options.
    // - Cutter and dispenser are field-installable: add them with `adding(_:)`.
    // - Link-OS firmware, "Unicode compliant": `^CI28` UTF-8 and `^CI27` code page 1252.
    //
    // The ZD420c (ribbon cartridge) speaks the same ZPL as the ZD420t; use the `t` profiles.

    private static let zd420Interfaces = Interfaces(
        standard: [.usb, .usbHost, .bluetoothLowEnergy],
        optional: [.ethernet, .serial, .wifi, .bluetoothClassic]
    )

    private static let zd420Capabilities: ZPLCapabilities = [.qrCodes, .graphicFields, .hostStatus]

    /// Zebra ZD420d, direct thermal, 203 dpi.
    public static let zebraZD420d203 = ZPLProfile(
        id: "zebra-zd420d-203dpi",
        name: "Zebra ZD420d (203 dpi)",
        resolution: .dpi203,
        capabilities: zd420Capabilities,
        characterEncodings: [.usa1, .windows1252, .utf8],
        defaultCharacterEncoding: .utf8,
        maximumPrintWidth: 832,
        maximumLabelLength: 7928,
        printSpeeds: 2...6,
        interfaces: zd420Interfaces,
        verification: .documented
    )

    /// Zebra ZD420d, direct thermal, 300 dpi.
    public static let zebraZD420d300 = ZPLProfile(
        id: "zebra-zd420d-300dpi",
        name: "Zebra ZD420d (300 dpi)",
        resolution: .dpi300,
        capabilities: zd420Capabilities,
        characterEncodings: [.usa1, .windows1252, .utf8],
        defaultCharacterEncoding: .utf8,
        maximumPrintWidth: 1228,
        maximumLabelLength: 11705,
        printSpeeds: 2...4,
        interfaces: zd420Interfaces,
        verification: .documented
    )

    /// Zebra ZD420t, thermal transfer (also prints direct thermal), 203 dpi.
    public static let zebraZD420t203 = ZPLProfile(
        id: "zebra-zd420t-203dpi",
        name: "Zebra ZD420t (203 dpi)",
        resolution: .dpi203,
        capabilities: zd420Capabilities.union(.thermalTransfer),
        characterEncodings: [.usa1, .windows1252, .utf8],
        defaultCharacterEncoding: .utf8,
        maximumPrintWidth: 832,
        maximumLabelLength: 7928,
        printSpeeds: 2...6,
        interfaces: zd420Interfaces,
        verification: .documented
    )

    /// Zebra ZD420t, thermal transfer (also prints direct thermal), 300 dpi.
    public static let zebraZD420t300 = ZPLProfile(
        id: "zebra-zd420t-300dpi",
        name: "Zebra ZD420t (300 dpi)",
        resolution: .dpi300,
        capabilities: zd420Capabilities.union(.thermalTransfer),
        characterEncodings: [.usa1, .windows1252, .utf8],
        defaultCharacterEncoding: .utf8,
        maximumPrintWidth: 1228,
        maximumLabelLength: 11705,
        printSpeeds: 2...4,
        interfaces: zd420Interfaces,
        verification: .documented
    )
}
