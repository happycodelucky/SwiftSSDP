//
//  MockTransport.swift
//  SwiftSSDP
//
//  Copyright © 2017-2026 Paul Bates. All rights reserved.
//

import Foundation
@testable import SwiftSSDP

/// In-memory ``SSDPTransport`` for tests.
///
/// Test code drives behavior by calling ``deliverSearchReply(_:)`` and
/// ``deliverNotify(_:)``; subscribers see those bytes flow through their streams as if
/// they had arrived from the network. The mock never touches a real socket.
///
/// `MockTransport` is an `actor` so test setup, mid-test injections, and concurrent
/// consumers can all coexist without data races. Failure modes (e.g. simulated multicast
/// join failure) can be primed before the discovery actor calls the transport.
actor MockTransport: SSDPTransport {

    // MARK: - Test instrumentation

    private var searchContinuations: [UUID: AsyncThrowingStream<SSDPDatagram, Error>.Continuation] = [:]
    private var multicastContinuations: [UUID: AsyncThrowingStream<SSDPDatagram, Error>.Continuation] = [:]

    /// Recorded outbound M-SEARCH messages, in order.
    private(set) var sentRequests: [SSDPMSearchRequest] = []

    /// If non-nil, the next call to ``multicastDatagrams()`` throws this error
    /// (and resets to `nil`).
    var multicastFailure: SSDPError? = nil

    /// If non-nil, the next call to ``sendSearch(_:)`` throws this error
    /// (and resets to `nil`).
    var sendFailure: SSDPError? = nil

    init() {}

    // MARK: - Test driving

    /// Deliver a datagram to all currently-subscribed search streams.
    func deliverSearchReply(_ raw: String, from source: String = "192.168.1.10:1900") {
        let datagram = SSDPDatagram(data: Data(raw.utf8), source: source)
        for cont in searchContinuations.values {
            cont.yield(datagram)
        }
    }

    /// Deliver a datagram to all currently-subscribed multicast (NOTIFY) streams.
    func deliverNotify(_ raw: String, from source: String = "192.168.1.10:1900") {
        let datagram = SSDPDatagram(data: Data(raw.utf8), source: source)
        for cont in multicastContinuations.values {
            cont.yield(datagram)
        }
    }

    /// Number of currently-subscribed multicast streams (for ref-count tests).
    var multicastSubscriberCount: Int { multicastContinuations.count }

    /// Number of currently-subscribed search streams.
    var searchSubscriberCount: Int { searchContinuations.count }

    /// Prime a multicast join failure for the next call.
    func setMulticastFailure(_ error: SSDPError?) {
        multicastFailure = error
    }

    /// Prime a send failure for the next call.
    func setSendFailure(_ error: SSDPError?) {
        sendFailure = error
    }

    // MARK: - SSDPTransport

    func sendSearch(_ request: SSDPMSearchRequest)
        async throws -> AsyncThrowingStream<SSDPDatagram, Error>
    {
        if let err = sendFailure {
            sendFailure = nil
            throw err
        }
        sentRequests.append(request)

        let id = UUID()
        let (stream, cont) = AsyncThrowingStream<SSDPDatagram, Error>.makeStream(
            bufferingPolicy: .bufferingNewest(256)
        )
        searchContinuations[id] = cont
        cont.onTermination = { [weak self] _ in
            Task { await self?.removeSearch(id: id) }
        }
        return stream
    }

    func multicastDatagrams()
        async throws -> AsyncThrowingStream<SSDPDatagram, Error>
    {
        if let err = multicastFailure {
            multicastFailure = nil
            throw err
        }
        let id = UUID()
        let (stream, cont) = AsyncThrowingStream<SSDPDatagram, Error>.makeStream(
            bufferingPolicy: .bufferingNewest(256)
        )
        multicastContinuations[id] = cont
        cont.onTermination = { [weak self] _ in
            Task { await self?.removeMulticast(id: id) }
        }
        return stream
    }

    private func removeSearch(id: UUID) {
        searchContinuations.removeValue(forKey: id)
    }

    private func removeMulticast(id: UUID) {
        multicastContinuations.removeValue(forKey: id)
    }
}
