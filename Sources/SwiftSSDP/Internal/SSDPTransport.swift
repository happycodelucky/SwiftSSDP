//
//  SSDPTransport.swift
//  SwiftSSDP
//
//  Copyright © 2017-2026 Paul Bates. All rights reserved.
//

import Foundation

/// A wire-level UDP datagram received from the network.
///
/// The transport returns these as opaque byte buffers; parsing into ``SSDPMessage``
/// happens one layer up. Source endpoint is captured for diagnostic logging.
struct SSDPDatagram: Sendable {
    let data: Data
    /// Best-effort source description (e.g. `"192.168.1.42:1900"`). Empty if unavailable.
    let source: String
}

/// The seam between ``SSDPDiscovery`` and the underlying network transport.
///
/// Production code uses ``NetworkTransport`` (built on `Network.framework`). Tests use
/// `MockTransport` to inject canned datagrams without touching the network.
///
/// Two responsibilities, deliberately on one protocol:
///
/// - ``sendSearch(_:)`` opens a transient unicast/multicast send for one M-SEARCH and
///   returns a stream of datagrams arriving on the source port (the unicast replies).
///   The stream finishes when the consumer cancels or the transport tears down.
/// - ``multicastDatagrams()`` returns the shared multicast NOTIFY stream. Multiple
///   callers fan out from one underlying socket.
protocol SSDPTransport: Sendable {
    /// Send a single M-SEARCH and start receiving unicast replies on its source port.
    ///
    /// The returned stream finishes (without throwing) when the consumer cancels its
    /// `for try await` loop. Throws if the connection setup fails.
    func sendSearch(_ request: SSDPMSearchRequest)
        async throws -> AsyncThrowingStream<SSDPDatagram, Error>

    /// Subscribe to the shared multicast NOTIFY stream.
    ///
    /// Multiple subscribers fan out from one underlying multicast group join; the join
    /// is reference-counted so the socket tears down when the last subscriber cancels.
    /// Throws if the multicast group cannot be joined (e.g. missing entitlement on iOS).
    func multicastDatagrams()
        async throws -> AsyncThrowingStream<SSDPDatagram, Error>
}
