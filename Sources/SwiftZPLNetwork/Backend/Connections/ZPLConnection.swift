//
//  ZPLConnection.swift
//  swift-zpl
//
//  Created by Damian Van de Kauter on 27/10/2026.
//

import NIOConcurrencyHelpers
import NIOCore
import NIOPosix
import SwiftZPL

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#endif

/// Where a printer is reached, and how to hand it bytes.
///
/// Every call opens one connection, does its work and closes it again, so a printer shared with
/// another system is held for as short a time as possible. Calls are not serialised: sending two
/// jobs to one printer at once is the caller's to prevent.
public struct ZPLConnection: Sendable, Hashable {
    /// Per-step time limits.
    public struct Timeouts: Sendable, Hashable {
        public var connect: Duration
        /// For each chunk to be accepted. A printer that stops reading — paused, out of media, a
        /// full buffer — stalls the write rather than failing it, so this is what notices.
        public var write: Duration
        public var statusRead: Duration

        public init(
            connect: Duration = .seconds(5),
            write: Duration = .seconds(10),
            statusRead: Duration = .seconds(3)
        ) {
            self.connect = connect
            self.write = write
            self.statusRead = statusRead
        }
    }

    enum Endpoint: Sendable, Hashable {
        case tcp(host: String, port: Int)
    }

    let endpoint: Endpoint
    public var timeouts: Timeouts
    /// Bytes per write. Each chunk is confirmed before the next, which is what lets a failure say
    /// how much was accepted.
    public var chunkSize: Int

    /// A printer on the network, normally on raw port 9100.
    ///
    /// Only a printer with a network interface — on a ZD420, the Ethernet or Wi-Fi option — has
    /// the port, and it can be disabled in the printer's settings.
    public static func tcp(
        host: String,
        port: Int = 9100,
        timeouts: Timeouts = Timeouts(),
        chunkSize: Int = 4096
    ) -> ZPLConnection {
        ZPLConnection(endpoint: .tcp(host: host, port: port), timeouts: timeouts, chunkSize: chunkSize)
    }

    // MARK: - Sending

    /// Sends a job and closes the connection.
    ///
    /// Success means every byte was accepted and the connection closed cleanly — not that a label
    /// printed. On failure, ``ZPLConnectionError/delivery`` says whether sending again could print
    /// labels twice.
    public func send(_ bytes: [UInt8]) async throws(ZPLConnectionError) -> ZPLTransmission {
        let clock = ContinuousClock()
        let start = clock.now
        let progress = Progress()
        do {
            try Task.checkCancellation()
            let channel = try await connect()
            defer { channel.close(promise: nil) }
            try await withTaskCancellationHandler {
                progress.phase = .writing
                var offset = 0
                while offset < bytes.count {
                    try Task.checkCancellation()
                    let end = min(offset + max(chunkSize, 1), bytes.count)
                    progress.hasStartedWriting = true
                    try await write(bytes[offset..<end], on: channel, progress: progress)
                    progress.confirmedBytes = end
                    offset = end
                }
                try await channel.close()
            } onCancel: {
                progress.wasCancelled = true
                channel.close(promise: nil)
            }
            return ZPLTransmission(bytesSent: bytes.count, duration: clock.now - start)
        } catch {
            throw progress.classify(error)
        }
    }

    /// Asks the printer for its host status (`~HS`) and closes the connection.
    ///
    /// Only meaningful for a profile listing ``ZPLCapabilities/hostStatus``. A printer that does
    /// not answer fails with ``ZPLConnectionError/Reason/timedOut(_:)`` while reading — and Zebra
    /// printers stay silent in some fault states, so treat that as "not known to be ready". No job
    /// bytes are involved, so the delivery of a failure is always
    /// ``ZPLConnectionError/Delivery/notSent``.
    public func status() async throws(ZPLConnectionError) -> ZPLHostStatus {
        let progress = Progress(countsDelivery: false)
        do {
            try Task.checkCancellation()
            let channel = try await connect()
            defer { channel.close(promise: nil) }
            return try await withTaskCancellationHandler {
                let answer = channel.eventLoop.makePromise(of: [UInt8].self)
                try await channel.eventLoop.submit {
                    try channel.pipeline.syncOperations.addHandler(ZPLStatusCollector(promise: answer))
                }.get()

                progress.phase = .writing
                try await write(ZPLHostStatus.request[...], on: channel, progress: progress)

                progress.phase = .readingStatus
                let deadline = channel.eventLoop.scheduleTask(in: TimeAmount(timeouts.statusRead)) {
                    progress.hasTimedOut = true
                    answer.fail(ChannelError.ioOnClosedChannel)
                }
                defer { deadline.cancel() }
                let bytes = try await answer.futureResult.get()
                return try ZPLHostStatus(response: bytes)
            } onCancel: {
                progress.wasCancelled = true
                channel.close(promise: nil)
            }
        } catch {
            throw progress.classify(error)
        }
    }

    // MARK: - Channel

    private func connect() async throws -> Channel {
        switch endpoint {
        case .tcp(let host, let port):
            try await ClientBootstrap(group: MultiThreadedEventLoopGroup.singleton)
                .connectTimeout(TimeAmount(timeouts.connect))
                .channelOption(ChannelOptions.socketOption(.tcp_nodelay), value: 1)
                .connect(host: host, port: port)
                .get()
        }
    }

    private func write(_ chunk: ArraySlice<UInt8>, on channel: Channel, progress: Progress) async throws {
        let deadline = channel.eventLoop.scheduleTask(in: TimeAmount(timeouts.write)) {
            progress.hasTimedOut = true
            channel.close(promise: nil)
        }
        defer { deadline.cancel() }
        try await channel.writeAndFlush(ByteBuffer(bytes: chunk)).get()
    }
}

// MARK: - Progress

extension ZPLConnection {
    /// What a call had got to when it failed, shared with the event loop's timeout callbacks.
    final class Progress: Sendable {
        private struct State {
            var phase: ZPLConnectionError.Phase = .connecting
            var hasStartedWriting = false
            var confirmedBytes = 0
            var hasTimedOut = false
            /// Set by the cancellation handler, which closes the channel: the step then fails with
            /// a closed-channel error, not a `CancellationError`, and must still count as cancelled.
            var wasCancelled = false
        }

        private let state = NIOLockedValueBox(State())
        private let countsDelivery: Bool

        init(countsDelivery: Bool = true) {
            self.countsDelivery = countsDelivery
        }

        var phase: ZPLConnectionError.Phase {
            get { state.withLockedValue(\.phase) }
            set { state.withLockedValue { $0.phase = newValue } }
        }

        var hasStartedWriting: Bool {
            get { state.withLockedValue(\.hasStartedWriting) }
            set { state.withLockedValue { $0.hasStartedWriting = newValue } }
        }

        var confirmedBytes: Int {
            get { state.withLockedValue(\.confirmedBytes) }
            set { state.withLockedValue { $0.confirmedBytes = newValue } }
        }

        var hasTimedOut: Bool {
            get { state.withLockedValue(\.hasTimedOut) }
            set { state.withLockedValue { $0.hasTimedOut = newValue } }
        }

        var wasCancelled: Bool {
            get { state.withLockedValue(\.wasCancelled) }
            set { state.withLockedValue { $0.wasCancelled = newValue } }
        }

        /// Turns whatever was thrown into a ``ZPLConnectionError`` that is honest about delivery.
        ///
        /// Once a write has been issued, a failure is never ``ZPLConnectionError/Delivery/notSent``:
        /// the operating system may have sent part of a chunk whose write then failed.
        func classify(_ error: any Error) -> ZPLConnectionError {
            let state = state.withLockedValue { $0 }
            let delivery: ZPLConnectionError.Delivery =
                countsDelivery && state.hasStartedWriting
                ? .partiallySent(confirmedBytes: state.confirmedBytes)
                : .notSent
            return ZPLConnectionError(delivery: delivery, reason: reason(for: error, state: state))
        }

        private func reason(for error: any Error, state: State) -> ZPLConnectionError.Reason {
            if let error = error as? ZPLStatusError {
                return .malformedStatus(error)
            }
            if error is CancellationError || state.wasCancelled {
                return .cancelled(state.phase)
            }
            if state.hasTimedOut {
                return .timedOut(state.phase)
            }
            if case ChannelError.connectTimeout = error {
                return .timedOut(.connecting)
            }
            if state.phase == .connecting {
                return Self.isRefusal(error) ? .connectionRefused : .connectionFailed(String(describing: error))
            }
            return .disconnected(state.phase)
        }

        private static func isRefusal(_ error: any Error) -> Bool {
            if let error = error as? IOError {
                return error.errnoCode == ECONNREFUSED
            }
            if let error = error as? NIOConnectionError {
                return !error.connectionErrors.isEmpty
                    && error.connectionErrors.allSatisfy { isRefusal($0.error) }
            }
            return false
        }
    }
}
