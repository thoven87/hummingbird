//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2023 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import NIOCore

public struct AvailableConnectionsHandlerFactory: Sendable {
    var createDelegate: @Sendable () -> any AvailableConnectionsDelegate

    public init(_ createDelegate: @escaping @Sendable () -> any AvailableConnectionsDelegate) {
        self.createDelegate = createDelegate
    }
}

extension AvailableConnectionsHandlerFactory {
    static func maximumAvailableConnections(_ maxConnections: Int) -> Self {
        return .init {
            MaximumAvailableConnections(maxConnections)
        }
    }
}

/// Delegate for `AvailableConnectionsChannelHandler` that defines if we should accept
public protocol AvailableConnectionsDelegate {
    /// Called when a connection is opened
    mutating func connectionOpened()
    /// Called when a connection is closed
    mutating func connectionClosed()
    /// Return whether we are accepting new connections
    func isAcceptingNewConnections() -> Bool
}

extension AvailableConnectionsDelegate {
    /// Create ChannelHandler from Delegate
    public var availableConnectionsChannelHandler: any ChannelDuplexHandler {
        AvailableConnectionsChannelHandler(delegate: self)
    }
}

/// Implementation of ``AvailableConnectionsDelegate`` that sets a maximum limit to the number
/// of open connections
struct MaximumAvailableConnections: AvailableConnectionsDelegate {
    let maxConnections: Int
    var connectionCount: Int

    init(_ maxConnections: Int) {
        self.maxConnections = maxConnections
        self.connectionCount = 0
    }

    mutating func connectionOpened() {
        self.connectionCount += 1
    }

    mutating func connectionClosed() {
        self.connectionCount -= 1
    }

    func isAcceptingNewConnections() -> Bool {
        self.connectionCount < self.maxConnections
    }
}

/// Channel Handler that controls whether we should accept new connections
///
/// Handler is initialized with a delegate object that makes the decision on whether to accept a new connection
final class AvailableConnectionsChannelHandler<Delegate: AvailableConnectionsDelegate>: ChannelDuplexHandler {
    public typealias InboundIn = Channel
    public typealias InboundOut = Channel
    public typealias OutboundIn = Never
    public typealias OutboundOut = Never

    enum State {
        case available
        case waitingOnAvailability
    }

    var delegate: Delegate
    var state: State

    /// Initialize handler to only make a set number of connections available
    public init(maxConnections: Int) where Delegate == MaximumAvailableConnections {
        self.delegate = MaximumAvailableConnections(maxConnections)
        self.state = .available
    }

    /// Initialize handler with a delegate defining when connections are available
    public init(delegate: Delegate) {
        self.delegate = delegate
        self.state = .available
    }

    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let channel = self.unwrapInboundIn(data)
        let loopBoundValues = NIOLoopBoundBox((handler: self, context: context), eventLoop: context.eventLoop)
        self.delegate.connectionOpened()
        channel.closeFuture
            .hop(to: context.eventLoop)
            .whenComplete { _ in
                let values = loopBoundValues.value
                values.handler.delegate.connectionClosed()
                if values.handler.state == .waitingOnAvailability, values.handler.delegate.isAcceptingNewConnections() {
                    values.handler.state = .available
                    values.context.read()
                }
            }
        context.fireChannelRead(data)
    }

    public func read(context: ChannelHandlerContext) {
        guard self.delegate.isAcceptingNewConnections() else {
            self.state = .waitingOnAvailability
            return
        }
        context.read()
    }
}
