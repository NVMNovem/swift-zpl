//
//  ZPLHostStatus+Parsing.swift
//  swift-zpl
//
//  Created by Damian Van de Kauter on 27/10/2026.
//

extension ZPLHostStatus {
    /// Reads a complete `~HS` answer: three lines, each `STX`, comma-separated fields, `ETX`,
    /// usually followed by `CR LF`.
    ///
    /// Bytes outside the lines are ignored. A line with more fields than documented is accepted,
    /// since newer firmware may append some; one with fewer, or a flag that is not `0` or `1`, is
    /// refused rather than guessed at.
    public init(response: [UInt8]) throws(ZPLStatusError) {
        let lines = try Self.lines(in: response)
        guard lines.count == 3 else { throw .wrongLineCount(lines.count) }
        let first = try Self.fields(lines[0], line: 1, minimumCount: 12)
        let second = try Self.fields(lines[1], line: 2, minimumCount: 11)
        _ = try Self.fields(lines[2], line: 3, minimumCount: 2)

        self.init(
            isPaperOut: try first.flag(1),
            isPaused: try first.flag(2),
            labelLength: try first.number(3),
            formatsInReceiveBuffer: try first.number(4),
            isReceiveBufferFull: try first.flag(5),
            isInCommunicationsDiagnosticMode: try first.flag(6),
            isPartialFormatInProgress: try first.flag(7),
            isConfigurationCorrupt: try first.flag(9),
            isUnderTemperature: try first.flag(10),
            isOverTemperature: try first.flag(11),
            isHeadUp: try second.flag(2),
            isRibbonOut: try second.flag(3),
            isThermalTransferMode: try second.flag(4),
            printMode: PrintMode(code: second.values[5]),
            isLabelWaiting: try second.flag(7),
            labelsRemainingInBatch: try second.number(8),
            storedGraphicCount: try second.number(10)
        )
    }

    /// How many complete lines the bytes hold; a collector reads until this reaches three.
    static func completeLineCount(in bytes: [UInt8]) -> Int {
        bytes.lazy.filter { $0 == 0x03 }.count
    }

    // MARK: - Lines and fields

    private struct Fields {
        let line: Int
        let values: [String]

        func flag(_ index: Int) throws(ZPLStatusError) -> Bool {
            switch values[index] {
            case "0": return false
            case "1": return true
            default: throw .invalidField(line: line, index: index, value: values[index])
            }
        }

        func number(_ index: Int) throws(ZPLStatusError) -> Int {
            let value = values[index]
            guard !value.isEmpty, value.utf8.allSatisfy({ (0x30...0x39).contains($0) }),
                  let number = Int(value) else {
                throw .invalidField(line: line, index: index, value: value)
            }
            return number
        }
    }

    private static func lines(in bytes: [UInt8]) throws(ZPLStatusError) -> [[UInt8]] {
        var lines: [[UInt8]] = []
        var current: [UInt8]?
        for byte in bytes {
            switch byte {
            case 0x02:
                current = []
            case 0x03:
                if let line = current { lines.append(line) }
                current = nil
            default:
                current?.append(byte)
            }
        }
        guard current == nil else { throw .incompleteLine }
        return lines
    }

    private static func fields(
        _ line: [UInt8],
        line number: Int,
        minimumCount: Int
    ) throws(ZPLStatusError) -> Fields {
        let values = String(decoding: line, as: UTF8.self)
            .split(separator: ",", omittingEmptySubsequences: false)
            .map { $0.trimmingSpaces }
        guard values.count >= minimumCount else {
            throw .missingFields(line: number, count: values.count)
        }
        return Fields(line: number, values: values)
    }
}

extension ZPLHostStatus.PrintMode {
    init(code: String) {
        switch code {
        case "0": self = .rewind
        case "1": self = .peelOff
        case "2": self = .tearOff
        case "3": self = .cutter
        case "4": self = .applicator
        case "5": self = .delayedCut
        case "6": self = .linerlessPeel
        case "7": self = .linerlessRewind
        case "8": self = .partialCutter
        case "9": self = .rfid
        case "K": self = .kiosk
        default: self = .other(code)
        }
    }
}

private extension Substring {
    var trimmingSpaces: String {
        String(drop { $0 == " " }.reversed().drop { $0 == " " }.reversed())
    }
}
