//
//  ZPLConnectionError.swift
//  swift-zpl
//
//  Created by Damian Van de Kauter on 27/10/2026.
//

import SwiftZPL

/// Why talking to a printer failed, and — the part a caller must act on — whether any of the job
/// may have reached it.
public struct ZPLConnectionError: Error, Sendable, Hashable {
    /// How far the job's bytes got before the failure.
    public enum Delivery: Sendable, Hashable {
        /// No byte was handed to the network. Sending again cannot print the job twice.
        case notSent
        /// Writing had started. `confirmedBytes` were accepted by the operating system; more may
        /// have left. The printer may have printed some, all or none of the labels: every complete
        /// `^XA … ^XZ` it received is printed, a format cut off before `^XZ` is not.
        case partiallySent(confirmedBytes: Int)
    }

    /// The step that failed.
    public enum Phase: Sendable, Hashable {
        case connecting
        case writing
        case readingStatus
    }

    public enum Reason: Sendable, Hashable {
        /// Nothing accepts connections at the address and port.
        case connectionRefused
        /// The connection could not be made, for the reason described.
        case connectionFailed(String)
        /// The step took longer than its timeout. While reading status this may mean the printer
        /// chose not to answer, which Zebra printers do in several fault states.
        case timedOut(Phase)
        case cancelled(Phase)
        /// The connection closed or broke before the step finished.
        case disconnected(Phase)
        /// The printer answered `~HS` with something that is not a host status.
        case malformedStatus(ZPLStatusError)
    }

    public let delivery: Delivery
    public let reason: Reason

    public init(delivery: Delivery, reason: Reason) {
        self.delivery = delivery
        self.reason = reason
    }
}
