# swift-zpl

A type-safe Swift library for Zebra Programming Language II (ZPL II). You describe a label as values, the encoder turns it into deterministic ZPL for one printer model, and an optional TCP transport delivers it and asks the printer for status.

The first target printer is the **Zebra ZD420**. It has profiles built from Zebra's documentation, but **no hardware test has been run yet**. See [Hardware validation](Docs/HardwareValidation.md).

`swift-zpl` stands alone. It does not depend on `swift-print`, `swift-escpos` or any application. Its architecture follows `swift-escpos`; see [Architecture](Docs/Architecture.md).

## Requirements

- Swift 6.2 tools or later, Swift 6 language mode (strict concurrency).
- iOS 17, macOS 14, tvOS 17, watchOS 10, visionOS 1, and Linux. The full suite passes on macOS (arm64). On Linux it has only run as x86_64 under emulation: `SwiftZPL` builds and passes there, but the network tests fail on `setsockopt` under the emulator. A native Linux ARM64 run is still to do.
- `SwiftZPL` has no dependencies and imports no Foundation. `SwiftZPLNetwork` uses SwiftNIO.

## Installation

```swift
dependencies: [
    .package(url: "https://github.com/NVMNovem/swift-zpl.git", from: "0.1.0"),
],
targets: [
    .target(name: "App", dependencies: [
        .product(name: "SwiftZPL", package: "swift-zpl"),         // label generation
        .product(name: "SwiftZPLNetwork", package: "swift-zpl"),  // optional: TCP printing and status
    ]),
]
```

| Product | Contains | Dependencies |
|---|---|---|
| `SwiftZPL` | Commands, labels, encoder, profiles, `~HS` parsing | none |
| `SwiftZPLNetwork` | `ZPLConnection`: TCP send and status | SwiftNIO |

## Generating ZPL

```swift
import SwiftZPL

let label = ZPLLabel([
    .text(ZPLText("Product 1042", at: ZPLPosition(x: 40, y: 40))),
    .barcode(.code128("1042", at: ZPLPosition(x: 40, y: 120), height: 80)),
])

let encoder = ZPLEncoder(profile: .zebraZD420d203)
let bytes = try encoder.encode(label)
// ^XA^CI28^FO40,40^A0N,30,30^FDProduct 1042^FS^FO40,120^BY2^BCN,80,Y,N,N,A^FD1042^FS^XZ
```

A `ZPLLabel` is one format, `^XA … ^XZ`. It has an array of `ZPLCommand` values, a print quantity (`^PQ`) and a character set (`^CI`). `ZPLLabel` writes the start and end of the format itself, so a label can never be left open. To send several labels as one job, call `encode(_ labels: [ZPLLabel])`.

The output is always printable ASCII, and the same label and profile always give the same bytes. The encoder writes every parameter out instead of relying on printer defaults. It always sends `^CI`, so a label never depends on what an earlier job left selected.

### A complete product label

A 100 × 60 mm label at 203 dpi, with Dutch/French text, a price in euros, an EAN-13 and a QR code. The test suite checks this exact output (`ZPLEncoderTests.productLabel`).

```swift
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

let zpl = try ZPLEncoder(profile: .zebraZD420d203).encode(label)
```

```
^XA^CI28^PW800^LL480^MNY
^FO16,16^GB768,448,3,B,0^FS
^FO40,40^A0N,48,48^FH_^FDCr_C3_A8me br_C3_BBl_C3_A9e^FS
^FO40,104^A0N,28,28^FH_^FDArt. 1042 _C2_B7 4 _C3_97 90 g^FS
^FO480,40^A0N,64,64^FB280,1,0,R,0^FH_^FD_E2_82_AC 4,95^FS
^FO40,176^BY2^BEN,120,Y,N^FD590123412345^FS
^FO560,176^BQN,2,4^FDMA,https://example.com/p/1042^FS
^PQ2^XZ
```

(The line breaks are added here for reading. The encoder emits none.)

### Commands

| Command | ZPL | Notes |
|---|---|---|
| `.labelHome(_:)` | `^LH` | Origin for all later positions |
| `.printWidth(_:)` | `^PW` | ≤ profile's `maximumPrintWidth` |
| `.labelLength(_:)` | `^LL` | ≤ profile's `maximumLabelLength` |
| `.printOrientation(_:)` | `^PO` | Normal or inverted |
| `.mediaTracking(_:)` | `^MN` | Continuous, gap/notch, black mark |
| `.mediaType(_:)` | `^MT` | Thermal transfer needs `.thermalTransfer` |
| `.printMode(_:)` | `^MM` | Peel-off needs `.peeler`, cutter needs `.cutter` |
| `.printSpeed(inchesPerSecond:)` | `^PR` | Within profile's `printSpeeds` |
| `.darkness(_:)` | `~SD` | 0…30 |
| `.text(_:)` | `^FO ^A [^FB] ^FD ^FS` | Font, size, rotation; block for wrapping and alignment |
| `.barcode(_:)` | `^BY` + `^BC` / `^B3` / `^BE` | Code 128, Code 39, EAN-13 |
| `.qrCode(_:)` | `^BQ` | Model 2, automatic input mode; needs `.qrCodes` |
| `.box(_:)` | `^GB` | Boxes, frames, horizontal and vertical lines |
| `.graphic(_:)` | `^GFA` | 1-bit raster, inline ASCII hex; needs `.graphicFields` |
| `.raw(_:)` | as given | Escape hatch, see below |

The setup commands (`^PW`, `^LL`, `^MN`, `^MT`, `^MM`, `^PR`, `~SD`) change the printer's *current* settings. Those settings stay in effect for later labels until changed or until the printer restarts. This library never sends `^JUS`, so nothing is saved permanently.

### Barcodes

```swift
.barcode(.code128("ORD-2026-1042", at: ZPLPosition(x: 40, y: 40), height: 80))
.barcode(.code39("ABC-123", at: ZPLPosition(x: 40, y: 140), height: 60, checkDigit: true, wideBarRatio: 2.5))
.barcode(.ean13("5901234123457", at: ZPLPosition(x: 40, y: 220), height: 100, interpretation: .none))
.qrCode(ZPLQRCode("https://example.com/p/1042", at: ZPLPosition(x: 500, y: 40),
                  magnification: 5, errorCorrection: .high))
```

Barcode data is validated when you encode. Invalid data fails with `ZPLEncodingError.invalidBarcodeData` instead of printing a code that scans as something else:

- **Code 128** accepts printable ASCII, except `>`. ZPL reserves `>` for subset switching, so it is refused rather than passed through.
- **Code 39** accepts `0-9 A-Z`, space and `- . $ / + %`. Lowercase letters are refused, not converted to uppercase.
- **EAN-13** takes 12 digits, or 13 digits with a correct check digit. The printer computes the check digit itself.
- **QR** data is limited to the version-40 byte-mode capacity for the chosen error-correction level. After escaping, it must also fit the 3072 bytes that `^FD` takes.

### Escape hatch

`.raw("^FO10,10^GC50,2,B^FS")` sends ZPL exactly as written. It must be printable ASCII and start with `^` or `~`. It is refused if it would break the label around it:

- it starts or ends a format (`^XA`, `^XZ`)
- it changes the prefix or delimiter characters (`^CC`, `^CD`, `^CT`, or their `~` forms)
- it leaves a field open (`^FD`/`^FV` without a later `^FS`)

The encoder does not check anything beyond that. Field data inside raw ZPL is **not** escaped, and commands that reset the printer or save settings are allowed. Never build raw ZPL from text a user typed.

## Units and resolution

ZPL positions everything in printer dots. `ZPLLength` is `.dots`, `.millimeters` or `.inches`, and an integer literal means dots.

```swift
let position = ZPLPosition(x: .millimeters(10), y: .millimeters(15))
// 203 dpi: ^FO80,120     300 dpi: ^FO118,177
```

- Conversion always uses the resolution in the encoder's profile. The library never assumes 203 dpi.
- `.dpi203` is exactly 8 dots/mm (203.2 dpi), as Zebra defines it. `.dpi300` uses the exact 300 / 25.4 ≈ 11.81 dots/mm. Zebra's spec sheet rounds this to "12 dots/mm".
- Each length rounds to the nearest dot on its own, with halves rounded away from zero. For example, 0.0625 mm at 203 dpi is 1 dot. Two lengths that add up on paper can therefore differ by one dot once converted.
- A length that is not finite (NaN, infinity) fails with `.invalidLength`. Values outside the range ZPL or the profile allows fail with `.outOfRange`, which reports the value in dots. A field's `x` must fall inside the printhead width.

## Text and character encoding

Field data is never interpreted as ZPL. The rules:

- `^`, `~`, and every byte outside printable ASCII are sent as `^FH` hex escapes (`_5E`, `_C3_A9`). Whenever escapes are used, the escape character `_` is escaped too. As a result, text like `^XZ^XA~JR` prints literally (`^FH_^FD_5EXZ_5EXA_7EJR^FS`) and can never run as a command.
- A character the label's character set cannot hold fails with `.unencodableCharacter`. The encoder never substitutes `?`.
- Control characters (tab, escape, C1) fail with `.controlCharacter`.
- Line breaks are only allowed inside a `ZPLText.Block`, where they become `\&`, and inside QR data, where they become a line feed. A backslash inside a block is doubled, because `^FB` treats `\` as an escape character.
- A letter typed with a combining accent (`e` + U+0301) is encoded the same as the precomposed `é`.

| `ZPLCharacterEncoding` | ZPL | Holds | `€` | ZD420 |
|---|---|---|---|---|
| `.utf8` (ZD420 default) | `^CI28` | All of Unicode | `_E2_82_AC` | documented |
| `.windows1252` | `^CI27` | Western European, incl. all Dutch letters, `’`, `€` | `_80` | documented |
| `.usa1` | `^CI0` | Printable ASCII only (the library deliberately does not model the rest of the table) | refused | documented |

Whether a character set *contains* a character is a different question from whether the font can *draw* it. That depends on the printer's font, and the encoder cannot see it. A missing glyph prints as nothing, or as a box. Font `0`, the ZD420 default, is expected to cover Latin-1 and `€`. This is one of the hardware checks still to do.

## Printer profiles

```swift
ZPLProfile.zebraZD420d203   // direct thermal, 203 dpi
ZPLProfile.zebraZD420d300   // direct thermal, 300 dpi
ZPLProfile.zebraZD420t203   // thermal transfer, 203 dpi (also ZD420c cartridge)
ZPLProfile.zebraZD420t300   // thermal transfer, 300 dpi
ZPLProfile.generic          // unknown ZPL II printer: ASCII, no QR/graphics/status

// Options installed on this particular unit:
let profile = ZPLProfile.zebraZD420t203.adding([.cutter])
```

A profile is data. It holds the resolution, the capabilities, the allowed character sets, the maximum print width and label length, the speed range, the standard and optional interfaces, and a `verification` level (`.assumed`, `.documented`, `.hardwareTested(note)`). The encoder refuses any command whose capability the profile does not list. `id`s such as `zebra-zd420d-203dpi` are stable and safe to persist. Installed options are stored separately, because the `id` identifies the model, not the individual unit.

### Zebra ZD420

The numbers come from Zebra's ZD420 technical specifications and the ZPL II Programming Guide:

| | 203 dpi | 300 dpi |
|---|---|---|
| Print width | 104 mm = 832 dots | 104 mm = 1228 dots |
| Print length | 991 mm = 7928 dots | 991 mm = 11705 dots |
| Speed (`^PR`) | 2–6 in/s | 2–4 in/s |
| Variants | `d` direct thermal; `t` thermal transfer; `c` ribbon cartridge (same ZPL as `t`) | |
| Standard interfaces | USB 2.0, USB host, Bluetooth Low Energy | |
| Optional interfaces | Ethernet 10/100 or RS-232 serial (field-installable), Wi-Fi 802.11ac + Bluetooth 4.1 (factory) | |
| Media handling | Tear-off standard; cutter and dispenser (peeler) field-installable | |
| Firmware | Link-OS, ZPL II and EPL2, "Unicode compliant" | |

**Raw TCP requires a network option.** A ZD420 with only the standard interfaces has no port 9100. If the ZD420 has Ethernet or Wi-Fi installed, raw printing on port 9100 is normally enabled, but it can be turned off in the printer settings.

| Claim | Status |
|---|---|
| Resolutions, widths, lengths, speeds, interfaces, options | From Zebra documentation; not checked on hardware |
| `^CI28` / `^CI27` with `^FH` escapes print Dutch text and `€` | From documentation; **needs hardware test** |
| `~HS` answers over port 9100, in the documented format | From documentation; **needs hardware test** |
| 300 dpi conversion (11.81 vs 12 dots/mm) gives correct physical sizes | **Needs measurement** |
| Behaviour of `\\` and `\&` inside `^FB` when `^FH` is active | From documentation; **needs hardware test** |
| QR vertical offset relative to `^FO` | Known printer quirk; not corrected; **needs measurement** |
| Anything verified on physical hardware | **Nothing yet** |

## Network printing

```swift
import SwiftZPL
import SwiftZPLNetwork

let printer = ZPLConnection.tcp(host: "192.168.1.50")   // port 9100
let job = try ZPLEncoder(profile: .zebraZD420d203).encode(label)

do {
    let transmission = try await printer.send(job)
    print("Handed over \(transmission.bytesSent) bytes in \(transmission.duration)")
} catch {
    switch error.delivery {
    case .notSent:
        break   // safe to retry: nothing reached the printer
    case .partiallySent(let confirmed):
        break   // may already have printed: check status before retrying
    }
}
```

- Each call opens one connection, does its work and closes it, including after failures and cancellation. The tests verify that the connection is closed afterwards.
- `Timeouts` sets separate limits for connecting, for each chunk to be written, and for reading status. A printer that stops reading (paused, out of media) stalls the write instead of failing it, and the write timeout is what catches that.
- Cancelling the task cancels the call. A cancelled call reports `.cancelled(phase)` and keeps the delivery accounting correct.
- Calls are not serialised. Sending two jobs to one printer at the same time is up to the caller to prevent. The future `swift-print` print queue is the intended place for that.
- USB and Bluetooth are not implemented.

### Status and what "sent" means

```swift
let status = try await printer.status()     // ~HS
if !status.isReady { /* paper out, paused, head up, ribbon out, … */ }
if status.isIdle   { /* nothing buffered, no labels left in the batch */ }
```

| Signal | What it guarantees | What it does not |
|---|---|---|
| `send` returns `ZPLTransmission` | Every byte was accepted by the OS and the connection closed cleanly | That the printer parsed the ZPL, or that any label printed |
| `ZPLConnectionError.delivery == .notSent` | No byte left; retrying cannot print twice | — |
| `.partiallySent(confirmedBytes:)` | At least that many bytes were accepted | Whether the printer received them. Every complete `^XA … ^XZ` it got is printed |
| `status().isReady` | Nothing in `~HS` blocks printing at that moment | That the next label will print correctly |
| `status().isIdle` | No formats buffered or half-received, no batch labels left, no peeled label waiting | That a label printed *legibly*. Jams, tear-offs and missing ribbon look identical. Jobs from other senders count too |
| `status()` times out | The printer did not answer in time | That it is fine. **Zebra printers stay silent on `~HS` when out of media or ribbon, with the head open, the rewinder full, or the head too hot** |

ZPL over raw TCP has no acknowledgement for individual jobs. A reliable queue should do three things: send once, treat `.partiallySent` as "possibly printed", and confirm progress by polling `status()` until `isIdle`, accepting that this is evidence, not proof.

## Errors

All errors use typed throws and are `Hashable`, so they can be matched exactly:

- `ZPLEncodingError` covers a missing capability, an unsupported character set, an unencodable or control character, a misplaced line break, an out-of-range parameter (named by `Parameter`), invalid barcode data (with `BarcodeProblem`), QR or field data that is too large, and an invalid raw command (with `RawProblem`).
- `ZPLStatusError` is raised for an `~HS` answer that does not have the documented shape. Such answers are refused, not guessed at.
- `ZPLConnectionError` holds a `delivery` (`.notSent` / `.partiallySent`) and a `reason` (refused, failed, timed out, cancelled, disconnected, malformed status), each tagged with the phase it happened in.

## Supported and not supported

Supported in v0.1: label setup, text in resident fonts with rotation and field blocks, Code 128, Code 39, EAN-13, QR model 2, boxes and lines, inline 1-bit graphics, `^CI0/27/28`, `~HS` status, and raw TCP.

Not supported yet:

- other symbologies (DataMatrix, PDF417, UPC, GS1-128 with FNC1)
- Code 128 manual subsets
- downloadable fonts and `^A@`
- stored graphics and formats (`~DG`, `^XG`, `^DF`/`^XF`)
- serialisation (`^SN`)
- reverse print (`^FR`)
- circles and diagonals (use `.raw` for now)
- `~HQES` detailed error flags
- SGD (`! U1 getvar`)
- USB, Bluetooth and serial transports
- automatic glyph-coverage checks

## Known limitations

- The encoder cannot know which glyphs a font contains.
- QR codes print a few dots below their `^FO`. This is the printer's behaviour, and the library does not correct for it.
- Code 128 refuses `>` until the behaviour of automatic mode has been validated on hardware.
- `.usa1` is treated as ASCII-only. National substitutions and the upper half of the table are not modelled.
- Setup commands are not saved permanently, but they do persist until the printer restarts.

## Future swift-print integration

`swift-print` is meant to use `swift-zpl` as an optional backend, with the dependency running in one direction only: **Application → swift-print → swift-zpl**.

`swift-print` will own `PrintDocument`, `LabelLayout`, the declarative DSL, layout resolution and unified printer configuration. It will resolve a layout into `[ZPLCommand]` for a chosen `ZPLProfile`, encode the result with `ZPLEncoder`, and deliver it with `ZPLConnection`.

`swift-zpl` provides building blocks for that work:

- value types that are `Sendable` and `Hashable`
- profiles whose limits a layout engine can read
- errors that can be translated into higher-level errors
- delivery accounting a reliable queue can rely on

`swift-zpl` deliberately contains no generic document model, layout engine or DSL.
