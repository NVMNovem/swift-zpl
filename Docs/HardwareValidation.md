# Hardware validation: Zebra ZD420

These tests are manual and optional. They are not part of CI. **None of them has been run yet.** Until one has, every ZD420 claim in this package stays "documented, not verified". After a run, record it in the results table below. Change a profile's `verification` to `.hardwareTested(…)` only for what was actually observed.

## Before you start

Record these details. A result only applies to the configuration it was measured on.

| | |
|---|---|
| Model and variant (d / t / c) | |
| Resolution (203 / 300 dpi) | |
| Firmware version (from the configuration label) | |
| Installed interfaces (Ethernet / Wi-Fi / serial) | |
| Installed options (cutter / dispenser) | |
| Media (width × length, gap / mark / continuous, DT / TT) | |
| Host OS and Swift version | |
| Date and tester | |

Print a configuration label (hold FEED for about 2 s until the status light flashes once, then release). From it, record the firmware, the IP address, **PRINT WIDTH** in dots, and whether port 9100 / "RAW" is enabled.

The examples use a small executable package that depends on `SwiftZPL` and `SwiftZPLNetwork`. Choose the profile that matches the printer, for example `.zebraZD420d203`.

## 1. Connection

1. Run `nc -vz <ip> 9100`. **Expect:** the connection succeeds.
2. Run `try await ZPLConnection.tcp(host: ip).send(Array("^XA^XZ".utf8))`. **Expect:** it returns, and nothing prints.
3. Point the connection at a wrong port. **Expect:** `ZPLConnectionError(delivery: .notSent, reason: .connectionRefused)`.
4. Point it at an unused address on the same subnet. **Expect:** `.timedOut(.connecting)` after the connect timeout.

## 2. Basic text label

Send:

```swift
ZPLLabel([.text(ZPLText("Hello ZD420", at: ZPLPosition(x: 40, y: 40)))])
```

**Expect:** one label, with the text near the top-left corner and a height of about 30 dots (3.75 mm at 203 dpi).

## 3. Physical dimensions

Send a label with these commands:

- `.printWidth(.millimeters(100))`
- `.labelLength(.millimeters(60))`
- `.box(.horizontalLine(at: ZPLPosition(x: .millimeters(10), y: .millimeters(10)), length: .millimeters(80), thickness: 2))`
- `.box(.verticalLine(at: ZPLPosition(x: .millimeters(10), y: .millimeters(10)), length: .millimeters(40), thickness: 2))`

**Measure:** the horizontal line should be 80 mm ± 0.25 mm and the vertical line 40 mm ± 0.25 mm. Do this on **both** 203 and 300 dpi if available. On 300 dpi this checks the 300 / 25.4 conversion against Zebra's stated "12 dots/mm". Also check that `^PW` and the configuration label's PRINT WIDTH agree with the profile (832 / 1228 dots).

## 4. Code 128

Send `.barcode(.code128("ORD-2026-1042", at: ZPLPosition(x: 40, y: 40), height: 100))`.

**Expect:** a scanner reads `ORD-2026-1042`, and the interpretation line matches it.

Repeat with `"A^B_C~D"`. **Expect:** it scans as exactly `A^B_C~D`. This checks that `^FH` works inside `^BC`.

## 5. Code 39 and EAN-13

- `.code39("ABC-123", …, checkDigit: true)` should scan as `ABC-123` (some scanners also show the check character).
- `.ean13("5901234123457", …)` should scan as `5901234123457`.

## 6. QR code

1. Send `.qrCode(ZPLQRCode("https://example.com/p/1042", at: ZPLPosition(x: 40, y: 40), magnification: 5))`. **Expect:** a phone reads the URL.
2. Send `ZPLQRCode("Crème brûlée €4,95\nRegel 2", …)` in a UTF-8 label. **Expect:** the phone shows the exact text, accents and line break included.
3. **Measure** the gap between the `^FO` y-position and the top of the symbol. Record it as the QR offset.

## 7. Multiple labels and quantity

1. Send `ZPLLabel([...], quantity: 3)`. **Expect:** exactly 3 labels.
2. Send `encoder.encode([labelA, labelB])`. **Expect:** A, then B.
3. While printing, poll `status()`. **Expect:** `labelsRemainingInBatch` counts down, then `isIdle` becomes true.

## 8. Character encoding

Use the same text in three labels: `^CI28` (default), `.windows1252` and `.usa1`.

```
Crème brûlée · België · café · coördinatie · ’s-Hertogenbosch · € 4,95 · ÀÉÏÔÛ ç
```

- **Expect with UTF-8 and 1252:** every glyph appears correctly in font 0. Note any box or blank.
- **Expect with `.usa1`:** encoding fails with `.unencodableCharacter` before anything is sent.
- **Repeat** with the text inside a `ZPLText.Block(width: 600, maximumLines: 3)` that contains `\n` and a literal `\`. **Expect:** the line breaks appear, and a single backslash prints. This checks how `^FB` and `^FH` interact.
- **Injection:** print the text `^XZ^XA~JR`. **Expect:** it appears literally on the label, the printer does not reset, and the next label is unaffected.

## 9. Printer status

For each state, call `status()` and record the result: the fields, `isReady`, and whether the call timed out.

| State | Expected |
|---|---|
| Idle, media loaded | `isReady`, `isIdle` |
| Paused (press PAUSE) | `isPaused`, not ready |
| Head open | `isHeadUp`, **or a timeout**. Record which |
| Media out | `isPaperOut`, **or a timeout**. Record which |
| Ribbon out (t / c only, TT mode) | `isRibbonOut`, **or a timeout** |
| Printing a batch of 20 | `labelsRemainingInBatch > 0`, not idle |

Zebra documents that the printer may not answer `~HS` in fault states. Confirm the actual ZD420 behaviour here, because it decides how a queue should read a timeout.

## 10. Recovery after connection interruption

1. Start sending a large job: 50 labels, each with a 400 × 400 graphic.
2. Pull the network cable, or switch the printer off, mid-job. **Expect:** `send` fails with `.partiallySent(confirmedBytes:)` and either `.timedOut(.writing)` or `.disconnected(.writing)`, within the write timeout.
3. Restore the connection. **Expect:** `status()` works again. Record which labels printed (all complete `^XA…^XZ` formats received should print, and a cut-off format should not).
4. Pause the printer, then send a job large enough to fill its buffer. **Expect:** the write stalls, then `.timedOut(.writing)`.
5. Cancel a `send` task while it is stalled. **Expect:** `.cancelled(.writing)`.

## Results

| Date | Configuration | Test | Result | Notes |
|---|---|---|---|---|
| | | | | |
