//
//  MulticastListener.swift
//  SwiftSSDP
//
//  Copyright © 2017-2026 Paul Bates. All rights reserved.
//

import Foundation
import Network

/// Shared, ref-counted SSDP socket bound to the multicast group `239.255.255.250:1900`.
///
/// One `NWConnectionGroup` per process holds the IGMP membership, sends M-SEARCH
/// broadcasts, and receives every datagram destined for UDP/1900 — both unsolicited
/// NOTIFY multicasts *and* unicast M-SEARCH replies (which the kernel delivers to the
/// bound port irrespective of source address).
///
/// > Why this matters: an `NWConnection` "connected" to a multicast destination can send
/// > but cannot receive unicast replies from arbitrary sources, because Network.framework
/// > filters incoming datagrams against the connection's expected peer. A
/// > `NWConnectionGroup` has no such filter — every datagram arriving on its bound port
/// > is delivered to the receive handler. This single-socket design is therefore not just
/// > simpler than per-search `NWConnection`s, it's the only thing that actually works.
///
/// Subscribers fan out from the one socket. The group spins up on the first subscriber
/// and tears down when the last subscriber cancels.
///
/// On iOS / iPadOS / tvOS, joining `239.255.255.250` requires the
/// `com.apple.developer.networking.multicast` entitlement.
actor MulticastListener {

    enum State: Sendable {
        case idle
        case starting
        case ready
        case failed(SSDPError)
    }

    private var state: State = .idle
    private var group: NWConnectionGroup?

    /// All subscribers — both NOTIFY streams and per-search streams use the same fan-out
    /// machinery; filtering happens one layer up in ``SSDPDiscovery``.
    private var subscribers: [UUID: AsyncThrowingStream<SSDPDatagram, Error>.Continuation] = [:]

    private static let queue = DispatchQueue(
        label: "com.pryomoax.SwiftSSDP.MulticastListener",
        qos: .utility
    )

    init() {}

    // MARK: - Subscription

    /// Register a new subscriber and return its stream.
    ///
    /// Each subscriber receives every datagram the group sees — NOTIFY broadcasts and
    /// unicast M-SEARCH replies alike. Filtering by message type / search target is the
    /// caller's responsibility. The underlying group stays up as long as at least one
    /// subscriber exists.
    func subscribe() async throws -> AsyncThrowingStream<SSDPDatagram, Error> {
        let id = UUID()
        let (stream, continuation) = AsyncThrowingStream<SSDPDatagram, Error>.makeStream(
            bufferingPolicy: .bufferingNewest(256)
        )

        continuation.onTermination = { [weak self] _ in
            Task { await self?.unsubscribe(id: id) }
        }

        subscribers[id] = continuation

        switch state {
        case .idle:
            await start()
        case .starting, .ready:
            break
        case .failed(let error):
            // Reset and surface the error to this subscriber. Next call will retry.
            state = .idle
            continuation.finish(throwing: error)
            subscribers.removeValue(forKey: id)
            throw error
        }

        return stream
    }

    private func unsubscribe(id: UUID) {
        subscribers.removeValue(forKey: id)
        if subscribers.isEmpty {
            teardownGroup()
        }
    }

    // MARK: - Send

    /// Send a UDP datagram to the SSDP multicast endpoint via the shared group.
    ///
    /// If the group isn't ready yet, this method waits (with a short bound) for it to
    /// reach `.ready`. Throws if the group has failed.
    func send(_ data: Data) async throws {
        // Wait briefly for ready. The group is started lazily on first subscribe; if no
        // one has subscribed we cannot send — surface a clear error rather than silently
        // dropping.
        let waitDeadline = ContinuousClock.now + .seconds(2)
        while case .starting = state, ContinuousClock.now < waitDeadline {
            try await Task.sleep(for: .milliseconds(20))
        }

        switch state {
        case .ready:
            break
        case .failed(let err):
            throw err
        case .idle, .starting:
            throw SSDPError.transportFailed(
                details: "Multicast group not ready (state: \(state))"
            )
        }

        guard let group = self.group else {
            throw SSDPError.transportFailed(details: "Multicast group missing despite ready state")
        }

        let host = NWEndpoint.Host(SSDPMSearchRequest.ssdpHost)
        let port = NWEndpoint.Port(rawValue: UInt16(SSDPMSearchRequest.ssdpPort))!
        let endpoint = NWEndpoint.hostPort(host: host, port: port)

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            group.send(content: data, to: endpoint, completion: { error in
                if let error {
                    cont.resume(throwing: SSDPError.transportFailed(details: "\(error)"))
                } else {
                    cont.resume()
                }
            })
        }
    }

    // MARK: - Group lifecycle

    private func start() async {
        guard case .idle = state else { return }
        state = .starting

        do {
            let host = NWEndpoint.Host(SSDPMSearchRequest.ssdpHost)
            let port = NWEndpoint.Port(rawValue: UInt16(SSDPMSearchRequest.ssdpPort))!
            let multicast = try NWMulticastGroup(for: [.hostPort(host: host, port: port)])

            let params = NWParameters.udp
            params.allowLocalEndpointReuse = true
            let group = NWConnectionGroup(with: multicast, using: params)

            group.setReceiveHandler(maximumMessageSize: 65_507, rejectOversizedMessages: true)
            { [weak self] message, content, _ in
                guard let self, let data = content, !data.isEmpty else { return }
                let source = message.remoteEndpoint?.debugDescription ?? ""
                let datagram = SSDPDatagram(data: data, source: source)
                Task { await self.dispatch(datagram) }
            }

            group.stateUpdateHandler = { [weak self] newState in
                guard let self else { return }
                Task { await self.handle(state: newState) }
            }

            self.group = group
            group.start(queue: Self.queue)

        } catch {
            await fail(.multicastJoinFailed(details: "\(error)"))
        }
    }

    private func handle(state newState: NWConnectionGroup.State) async {
        switch newState {
        case .ready:
            self.state = .ready
            SSDPLog.listener.info("SSDP socket ready (multicast group joined)")
        case .failed(let error):
            await fail(mapError(error))
        case .cancelled, .setup, .waiting:
            break
        @unknown default:
            break
        }
    }

    /// Map an `NWError` to the closest `SSDPError`, recognizing the multicast-entitlement
    /// signature when possible.
    private func mapError(_ error: NWError) -> SSDPError {
        let raw = "\(error)"
        if raw.contains("multicast") || raw.contains("PolicyDenied")
            || raw.contains("operation not permitted")
        {
            return .multicastEntitlementMissing
        }
        return .multicastJoinFailed(details: raw)
    }

    private func fail(_ error: SSDPError) async {
        SSDPLog.listener.error("SSDP socket failed: \(String(describing: error), privacy: .public)")
        state = .failed(error)
        for cont in subscribers.values {
            cont.finish(throwing: error)
        }
        subscribers.removeAll()
        teardownGroup()
    }

    private func dispatch(_ datagram: SSDPDatagram) {
        // Snapshot to avoid mutation-during-iteration if a yield triggers a subscriber's
        // termination handler (which removes from the dictionary).
        let snapshot = Array(subscribers.values)
        for cont in snapshot {
            cont.yield(datagram)
        }
    }

    private func teardownGroup() {
        group?.cancel()
        group = nil
        state = .idle
    }
}
