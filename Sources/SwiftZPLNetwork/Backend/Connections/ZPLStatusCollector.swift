//
//  ZPLStatusCollector.swift
//  swift-zpl
//
//  Created by Damian Van de Kauter on 27/10/2026.
//

import NIOCore
import SwiftZPL

/// Collects a `~HS` answer on a channel: everything up to the third `ETX`.
final class ZPLStatusCollector: ChannelInboundHandler {
    typealias InboundIn = ByteBuffer

    /// Bytes beyond this without three complete lines are not a host status.
    static let maximumLength = 4096

    private let promise: EventLoopPromise<[UInt8]>
    private var received: [UInt8] = []
    private var isComplete = false

    init(promise: EventLoopPromise<[UInt8]>) {
        self.promise = promise
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        var buffer = unwrapInboundIn(data)
        if let bytes = buffer.readBytes(length: buffer.readableBytes) {
            received += bytes
        }
        if let end = Self.endOfThirdLine(in: received) {
            complete(.success(Array(received[..<end])))
        } else if received.count > Self.maximumLength {
            complete(.success(received))
        }
    }

    func channelInactive(context: ChannelHandlerContext) {
        complete(.failure(ChannelError.ioOnClosedChannel))
        context.fireChannelInactive()
    }

    func errorCaught(context: ChannelHandlerContext, error: Error) {
        complete(.failure(error))
        context.close(promise: nil)
    }

    /// The index just past the third `ETX`, once it has arrived.
    private static func endOfThirdLine(in bytes: [UInt8]) -> Int? {
        var count = 0
        for (index, byte) in bytes.enumerated() where byte == 0x03 {
            count += 1
            if count == 3 { return index + 1 }
        }
        return nil
    }

    /// Completes the promise once; later reads and closes are ignored.
    private func complete(_ result: Result<[UInt8], Error>) {
        guard !isComplete else { return }
        isComplete = true
        promise.completeWith(result)
    }
}
