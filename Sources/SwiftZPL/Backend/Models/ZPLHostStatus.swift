//
//  ZPLHostStatus.swift
//  swift-zpl
//
//  Created by Damian Van de Kauter on 27/10/2026.
//

/// What the printer reported in answer to `~HS`.
///
/// A snapshot, not an acknowledgement: it says what the printer's state was when it answered, not
/// whether a particular label came out. See ``isIdle`` for the closest it gets.
///
/// Zebra documents that a printer may not answer `~HS` at all while it is out of media or ribbon,
/// has its head open, its rewinder full or its head over temperature. Silence is therefore a
/// warning sign in itself, never a sign of readiness.
public struct ZPLHostStatus: Sendable, Hashable {
    /// The `r` field of the second line: what the printer does with a printed label.
    public enum PrintMode: Sendable, Hashable {
        case rewind
        case peelOff
        case tearOff
        case cutter
        case applicator
        case delayedCut
        case linerlessPeel
        case linerlessRewind
        case partialCutter
        case rfid
        case kiosk
        /// A code this library does not know, as the printer sent it.
        case other(String)
    }

    /// The three bytes that ask for host status.
    public static let request: [UInt8] = Array("~HS".utf8)

    // MARK: - Line 1

    public var isPaperOut: Bool
    public var isPaused: Bool
    /// The label length the printer is using, in dots.
    public var labelLength: Int
    /// Formats received and not yet processed.
    public var formatsInReceiveBuffer: Int
    public var isReceiveBufferFull: Bool
    public var isInCommunicationsDiagnosticMode: Bool
    /// A format has been started (`^XA`) and not yet ended.
    public var isPartialFormatInProgress: Bool
    /// The printer lost its configuration.
    public var isConfigurationCorrupt: Bool
    public var isUnderTemperature: Bool
    public var isOverTemperature: Bool

    // MARK: - Line 2

    public var isHeadUp: Bool
    public var isRibbonOut: Bool
    public var isThermalTransferMode: Bool
    public var printMode: PrintMode
    /// A peeled label is waiting to be taken.
    public var isLabelWaiting: Bool
    /// Labels of the current batch still to print.
    public var labelsRemainingInBatch: Int
    public var storedGraphicCount: Int

    public init(
        isPaperOut: Bool = false,
        isPaused: Bool = false,
        labelLength: Int = 0,
        formatsInReceiveBuffer: Int = 0,
        isReceiveBufferFull: Bool = false,
        isInCommunicationsDiagnosticMode: Bool = false,
        isPartialFormatInProgress: Bool = false,
        isConfigurationCorrupt: Bool = false,
        isUnderTemperature: Bool = false,
        isOverTemperature: Bool = false,
        isHeadUp: Bool = false,
        isRibbonOut: Bool = false,
        isThermalTransferMode: Bool = false,
        printMode: PrintMode = .tearOff,
        isLabelWaiting: Bool = false,
        labelsRemainingInBatch: Int = 0,
        storedGraphicCount: Int = 0
    ) {
        self.isPaperOut = isPaperOut
        self.isPaused = isPaused
        self.labelLength = labelLength
        self.formatsInReceiveBuffer = formatsInReceiveBuffer
        self.isReceiveBufferFull = isReceiveBufferFull
        self.isInCommunicationsDiagnosticMode = isInCommunicationsDiagnosticMode
        self.isPartialFormatInProgress = isPartialFormatInProgress
        self.isConfigurationCorrupt = isConfigurationCorrupt
        self.isUnderTemperature = isUnderTemperature
        self.isOverTemperature = isOverTemperature
        self.isHeadUp = isHeadUp
        self.isRibbonOut = isRibbonOut
        self.isThermalTransferMode = isThermalTransferMode
        self.printMode = printMode
        self.isLabelWaiting = isLabelWaiting
        self.labelsRemainingInBatch = labelsRemainingInBatch
        self.storedGraphicCount = storedGraphicCount
    }

    /// Whether a label sent now would print: nothing reported blocks it.
    ///
    /// The ribbon only counts in thermal-transfer mode. A full receive buffer counts, because a new
    /// job would wait behind it.
    public var isReady: Bool {
        !isPaperOut && !isPaused && !isHeadUp
            && !(isThermalTransferMode && isRibbonOut)
            && !isReceiveBufferFull && !isConfigurationCorrupt
            && !isUnderTemperature && !isOverTemperature
    }

    /// Whether the printer has nothing left to do: no format waiting or half received, no label
    /// of a batch left to print, none waiting to be taken.
    ///
    /// The closest `~HS` comes to "the job is done". It is still not proof that a label printed
    /// legibly — a label torn off, jammed or printed without ribbon looks the same — and a job sent
    /// by someone else is counted as well.
    public var isIdle: Bool {
        formatsInReceiveBuffer == 0 && labelsRemainingInBatch == 0
            && !isPartialFormatInProgress && !isLabelWaiting
    }
}
