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

import HummingbirdCore
import NIOCore
import NIOSSL

extension HBHTTPChannelBuilder {
    ///  Build HTTP channel with HTTP2 upgrade
    ///
    /// Use in ``Hummingbird/HBApplication`` initialization.
    /// ```
    /// let app = HBApplication(
    ///     router: router,
    ///     server: .http2(tlsConfiguration: tlsConfiguration)
    /// )
    /// ```
    /// - Parameters:
    ///   - tlsConfiguration: TLS configuration
    ///   - additionalChannelHandlers: Additional channel handlers to call before handling HTTP
    /// - Returns: HTTPChannelHandler builder
    public static func http2(
        tlsConfiguration: TLSConfiguration,
        additionalChannelHandlers: @autoclosure @escaping @Sendable () -> [any RemovableChannelHandler] = []
    ) throws -> HBHTTPChannelBuilder<HTTP2Channel> {
        return .init { responder in
            return try HTTP2Channel(
                tlsConfiguration: tlsConfiguration,
                additionalChannelHandlers: additionalChannelHandlers,
                responder: responder
            )
        }
    }
}
