//
//  ZPLConnectionTests.swift
//  swift-zpl
//
//  Created by Damian Van de Kauter on 27/10/2026.
//

import SwiftZPL
import Testing
@testable import SwiftZPLNetwork

/// Against ``VirtualPrinter`` on 127.0.0.1. What these prove is the delivery accounting — whether a
/// failure may already have printed something — and that every connection is closed afterwards.
@Suite("TCP connection")
struct ZPLConnectionTests {
    private func connection(
        port: Int,
        write: Duration = .seconds(5),
        statusRead: Duration = .seconds(2),
        chunkSize: Int = 4096
    ) -> ZPLConnection {
        .tcp(
            host: "127.0.0.1",
            port: port,
            timeouts: .init(connect: .seconds(2), write: write, statusRead: statusRead),
            chunkSize: chunkSize
        )
    }

    private static func hostStatus(
        _ first: String = "030,0,0,0480,000,0,0,0,000,0,0,0",
        second: String = "000,0,0,0,0,2,6,0,00000000,1,000"
    ) -> [UInt8] {
        [first, second, "1234,0"].flatMap { [0x02] + Array($0.utf8) + [0x03, 0x0D, 0x0A] }
    }

    // MARK: - Sending

    @Test("A job arrives byte for byte, and the connection is closed")
    func sendsEverything() async throws {
        let printer = try await VirtualPrinter.start(.accept)
        defer { Task { await printer.stop() } }
        let job = try ZPLEncoder(profile: .zebraZD420d203).encode(ZPLLabel([
            .text(ZPLText("Product 1042", at: ZPLPosition(x: 40, y: 40))),
            .barcode(.code128("1042", at: ZPLPosition(x: 40, y: 120), height: 80)),
        ]))

        let transmission = try await connection(port: printer.port, chunkSize: 8).send(job)

        #expect(transmission.bytesSent == job.count)
        #expect(await printer.received(atLeast: job.count) == job)
        #expect(await printer.allConnectionsClosed())
    }

    @Test("A refused connection sent nothing")
    func refused() async throws {
        let port = try await VirtualPrinter.closedPort()
        do {
            _ = try await connection(port: port).send(Array("^XA^XZ".utf8))
            Issue.record("Expected the connection to be refused")
        } catch {
            #expect(error == ZPLConnectionError(delivery: .notSent, reason: .connectionRefused))
        }
    }

    @Test("A printer that closes mid-job leaves a partial delivery, and the connection is closed")
    func resetMidJob() async throws {
        let printer = try await VirtualPrinter.start(.resetAfter(bytes: 1024))
        defer { Task { await printer.stop() } }
        let job = [UInt8](repeating: 0x41, count: 16 * 1024 * 1024)
        do {
            _ = try await connection(port: printer.port, chunkSize: 64 * 1024).send(job)
            Issue.record("Expected the reset to fail the job")
        } catch {
            guard case .partiallySent(let confirmed) = error.delivery else {
                Issue.record("Expected a partial delivery, got \(error.delivery)")
                return
            }
            #expect(confirmed < job.count)
            #expect(error.reason == .disconnected(.writing))
        }
        #expect(await printer.allConnectionsClosed())
    }

    @Test("A printer that stops reading times the write out, partially delivered")
    func stalledPrinter() async throws {
        let printer = try await VirtualPrinter.start(.neverRead)
        defer { Task { await printer.stop() } }
        let job = [UInt8](repeating: 0x41, count: 32 * 1024 * 1024)
        do {
            _ = try await connection(port: printer.port, write: .milliseconds(500), chunkSize: 64 * 1024).send(job)
            Issue.record("Expected the write to time out")
        } catch {
            guard case .partiallySent = error.delivery else {
                Issue.record("Expected a partial delivery, got \(error.delivery)")
                return
            }
            #expect(error.reason == .timedOut(.writing))
        }
    }

    @Test("Cancelling before connecting sends nothing")
    func cancelledBeforeSending() async throws {
        let printer = try await VirtualPrinter.start(.accept)
        defer { Task { await printer.stop() } }
        let connection = connection(port: printer.port)
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await connection.send(Array("^XA^XZ".utf8))
        }
        do {
            _ = try await task.value
            Issue.record("Expected cancellation")
        } catch let error as ZPLConnectionError {
            #expect(error == ZPLConnectionError(delivery: .notSent, reason: .cancelled(.connecting)))
        } catch {
            Issue.record("Unexpected error \(error)")
        }
        #expect(printer.received.isEmpty)
    }

    @Test("Cancelling a stalled write fails it as cancelled, partially delivered")
    func cancelledWhileWriting() async throws {
        let printer = try await VirtualPrinter.start(.neverRead)
        defer { Task { await printer.stop() } }
        let connection = connection(port: printer.port, write: .seconds(30), chunkSize: 64 * 1024)
        let job = [UInt8](repeating: 0x41, count: 32 * 1024 * 1024)
        let task = Task { try await connection.send(job) }
        try await Task.sleep(for: .milliseconds(300))
        task.cancel()
        do {
            _ = try await task.value
            Issue.record("Expected cancellation")
        } catch let error as ZPLConnectionError {
            guard case .partiallySent = error.delivery else {
                Issue.record("Expected a partial delivery, got \(error.delivery)")
                return
            }
            #expect(error.reason == .cancelled(.writing))
        } catch {
            Issue.record("Unexpected error \(error)")
        }
    }

    // MARK: - Status

    @Test("A host status answer is read and parsed, and the connection is closed")
    func status() async throws {
        let answer = Self.hostStatus("030,1,0,0480,000,0,0,0,000,0,0,0")
        let printer = try await VirtualPrinter.start(.answerHostStatus([answer]))
        defer { Task { await printer.stop() } }

        let status = try await connection(port: printer.port).status()

        #expect(status.isPaperOut)
        #expect(!status.isReady)
        #expect(await printer.received(atLeast: 3) == Array("~HS".utf8))
        #expect(await printer.allConnectionsClosed())
    }

    @Test("A host status arriving in pieces is put back together")
    func statusInPieces() async throws {
        let answer = Self.hostStatus()
        let pieces = stride(from: 0, to: answer.count, by: 5).map { Array(answer[$0..<min($0 + 5, answer.count)]) }
        let printer = try await VirtualPrinter.start(.answerHostStatus(pieces))
        defer { Task { await printer.stop() } }

        let status = try await connection(port: printer.port).status()

        #expect(status.isReady)
        #expect(status.isIdle)
    }

    @Test("A printer that never answers times out while reading, and nothing was sent")
    func silentStatus() async throws {
        let printer = try await VirtualPrinter.start(.accept)
        defer { Task { await printer.stop() } }
        do {
            _ = try await connection(port: printer.port, statusRead: .milliseconds(300)).status()
            Issue.record("Expected a status timeout")
        } catch {
            #expect(error == ZPLConnectionError(delivery: .notSent, reason: .timedOut(.readingStatus)))
        }
        #expect(await printer.allConnectionsClosed())
    }

    @Test("A printer that stops halfway through its answer times out")
    func truncatedStatus() async throws {
        let printer = try await VirtualPrinter.start(.answerHostStatus([Array(Self.hostStatus().prefix(40))]))
        defer { Task { await printer.stop() } }
        do {
            _ = try await connection(port: printer.port, statusRead: .milliseconds(300)).status()
            Issue.record("Expected a status timeout")
        } catch {
            #expect(error == ZPLConnectionError(delivery: .notSent, reason: .timedOut(.readingStatus)))
        }
    }

    @Test("A malformed status answer is refused, not misread")
    func malformedStatus() async throws {
        let answer = Self.hostStatus("030,x,0,0480,000,0,0,0,000,0,0,0")
        let printer = try await VirtualPrinter.start(.answerHostStatus([answer]))
        defer { Task { await printer.stop() } }
        do {
            _ = try await connection(port: printer.port).status()
            Issue.record("Expected a malformed status")
        } catch {
            let expected = ZPLStatusError.invalidField(line: 1, index: 1, value: "x")
            #expect(error == ZPLConnectionError(delivery: .notSent, reason: .malformedStatus(expected)))
        }
        #expect(await printer.allConnectionsClosed())
    }

    @Test("Asking a closed port for status sent nothing")
    func statusRefused() async throws {
        let port = try await VirtualPrinter.closedPort()
        do {
            _ = try await connection(port: port).status()
            Issue.record("Expected the connection to be refused")
        } catch {
            #expect(error == ZPLConnectionError(delivery: .notSent, reason: .connectionRefused))
        }
    }
}
