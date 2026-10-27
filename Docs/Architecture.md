# Architecture

`swift-zpl` uses `swift-escpos` as its reference architecture. It aims to be consistent with that package's design, not to copy its code. This note records which parts carried over, where `swift-zpl` departs from it and why, and one problem in the reference implementation.

## Kept from swift-escpos

| Convention | swift-escpos | swift-zpl |
|---|---|---|
| Tools and platforms | 6.2, iOS 17 / macOS 14 / tvOS 17 / watchOS 10 / visionOS 1, Swift 6 mode | Same, unchanged |
| Commands as values | `enum ESCPOSCommand` | `enum ZPLCommand` |
| Strict encoder bound to a profile | `ESCPOSEncoder(profile:)` refuses commands that are not listed | `ZPLEncoder(profile:)`, same rule |
| Profile as data, stable persisted `id`, `builtin` list | `ESCPOSProfile` | `ZPLProfile` |
| Capabilities as an `OptionSet` | `ESCPOSCapabilities` | `ZPLCapabilities` |
| Typed throws, `Hashable` errors | `throws(ESCPOSEncodingError)` | `throws(ZPLEncodingError)` |
| Text cannot smuggle commands | Code page encoder maps control characters to `?` | `^FH` hex escaping, see below |
| One connection per call, honest delivery accounting | `ESCPOSConnection`, `Delivery.notSent / .partiallySent` | `ZPLConnection`, same model |
| SwiftNIO for TCP, `NIOLockedValueBox` for shared progress state | ✓ | ✓ |
| "Sent" is not "printed" | `ESCPOSTransmission` | `ZPLTransmission` |
| Tests | Swift Testing, golden bytes, a loopback `VirtualPrinter` that misbehaves on purpose | Same approach |
| Folder layout | `Backend/{Types,Models,Models/Errors,Encoders,Connections,Extensions}` | Same |

## Deviations

1. **Two targets instead of one.** `SwiftESCPOS` combines encoding and NIO transport in a single target, so the encoder cannot be used without linking SwiftNIO. `swift-zpl` splits them:
   - `SwiftZPL` is pure, has no dependencies and does no I/O.
   - `SwiftZPLNetwork` holds the NIO transport.

   SwiftPM still *resolves* swift-nio for any client of the package. A package trait could remove that later. Traits are not used now because `swift-escpos` does not use them either.

2. **A label type around the commands.** ESC/POS is a byte stream with no frames. ZPL works in formats (`^XA … ^XZ`). `ZPLLabel` owns that framing, plus `^CI` and `^PQ`, which are properties of each label. This makes an unbalanced format impossible to express.

3. **Physical units.** ESC/POS work happens in character columns, but ZPL positions everything in dots. `ZPLLength` (`.dots`, `.millimeters`, `.inches`) is converted using the profile's `ZPLResolution`. Because the profile owns the resolution, the encoder can never assume 203 dpi by accident.

4. **No silent replacement of characters.** `ESCPOSCodePage` transliterates and falls back to `?` while reporting replacements. That suits receipts. On labels, a wrong character can be a wrong allergen or a wrong price, so `swift-zpl` refuses an unencodable character with an error.

5. **Field data escaping instead of byte filtering.** The command prefixes `^` and `~`, and every non-ASCII byte, are sent as `^FH` hex escapes. The printer decodes these escapes only after it has parsed the field, so the command stream itself stays printable ASCII.

6. **Validated escape hatch.** `ESCPOSCommand.raw([UInt8])` is unchecked. `ZPLCommand.raw(String)` refuses only what would break the encoder's own framing, as listed in the README. Everything else stays the caller's responsibility, as documented.

7. **Errors without embedded commands.** `ESCPOSEncodingError.unsupported` carries the whole failing command, including image data. `ZPLEncodingError` names the missing capability or the `Parameter` instead. This keeps errors small, and they remain exact enough for tests.

8. **Status format.** `DLE EOT` answers are one byte each. `~HS` returns three `STX … ETX` text lines, which the collector reads until the third `ETX` and caps at 4 KiB. The parser rejects any line that has fewer fields than documented.

## Problem found in the reference

`ESCPOSConnection` misreports cancellation that happens during a write.

When the task is cancelled, the `onCancel` handler closes the channel. The pending `writeAndFlush` then fails with a closed-channel error, not a `CancellationError`. As a result, `Progress.classify` reports `.disconnected(.writing)` instead of `.cancelled(.writing)`.

`swift-zpl` fixes this: `onCancel` sets a `wasCancelled` flag before closing the channel, and `classify` checks that flag. The test `cancelledWhileWriting` exposed the bug and now covers it. The same fix would apply to `swift-escpos`, which this work did not modify.

## Public API at a glance

```
SwiftZPL
  ZPLLabel(commands, quantity:, characterEncoding:)
  ZPLCommand: labelHome printWidth labelLength printOrientation mediaTracking mediaType
              printMode printSpeed darkness text barcode qrCode box graphic raw
  ZPLText(+Block)  ZPLBarcode(.code128/.code39/.ean13)  ZPLQRCode  ZPLBox  ZPLGraphic  ZPLRasterImage
  ZPLLength  ZPLPosition  ZPLResolution  ZPLFont  ZPLOrientation  ZPLTextAlignment
  ZPLCharacterEncoding  ZPLMediaTracking  ZPLMediaType  ZPLPrintMode  ZPLPrintOrientation
  ZPLProfile(+builtin, adding)  ZPLCapabilities  ZPLInterface
  ZPLEncoder(profile:).encode(_:)
  ZPLHostStatus(response:)  ZPLHostStatus.request
  ZPLEncodingError  ZPLStatusError

SwiftZPLNetwork
  ZPLConnection.tcp(host:port:timeouts:chunkSize:)  .send(_:)  .status()
  ZPLTransmission  ZPLConnectionError
```
