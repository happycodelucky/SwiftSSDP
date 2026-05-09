//
//  NetworkTransport.swift
//  SwiftSSDP
//
//  Copyright © 2017-2026 Paul Bates. All rights reserved.
//

import Foundation
import Network

/// Production ``SSDPTransport`` — a thin wrapper around a single shared
/// ``MulticastListener``.
///
/// Both M-SEARCH and NOTIFY traffic flows through one socket: the multicast group at
/// `239.255.255.250:1900`. Every datagram (multicast NOTIFY, our looped-back M-SEARCH,
/// unicast replies from devices) lands in the listener's receive handler and fans out to
/// all subscribers. Filtering by message type / search target happens one layer up in
/// ``SSDPDiscovery``.
///
/// > Earlier versions of this transport tried to use per-search `NWConnection`s for
/// > M-SEARCH. That doesn't work — `NWConnection` filters incoming datagrams against the
/// > connection's expected peer, and unicast replies from device IPs don't match the
/// > multicast destination peer. Use `NWConnectionGroup` for everything.
final class NetworkTransport: SSDPTransport, Sendable {

    private let listener = MulticastListener()

    init() {}

    // MARK: - SSDPTransport

    func sendSearch(_ request: SSDPMSearchRequest)
        async throws -> AsyncThrowingStream<SSDPDatagram, Error>
    {
        // Subscribe first so we don't miss replies that arrive before send completes.
        let stream = try await listener.subscribe()
        try await listener.send(Data(request.message.utf8))
        return stream
    }

    func multicastDatagrams()
        async throws -> AsyncThrowingStream<SSDPDatagram, Error>
    {
        try await listener.subscribe()
    }
}
