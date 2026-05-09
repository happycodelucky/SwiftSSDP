//
//  SSDPDiscovery.swift
//  SwiftSSDP
//
//  Copyright © 2017-2026 Paul Bates. All rights reserved.
//

import Foundation

/// Entry point for SSDP discovery — both active M-SEARCH and passive NOTIFY listening.
///
/// Two operations:
///
/// - ``search(for:maxWait:timeout:)`` (and the request-form ``search(_:timeout:)``) sends
///   M-SEARCH broadcasts and yields the matching responses as an
///   `AsyncThrowingStream<SSDPMSearchResponse, Error>`. The stream finishes when the
///   timeout elapses or the consumer breaks the `for try await` loop.
///
/// - ``notifications()`` returns a long-lived `AsyncThrowingStream<SSDPNotification, Error>`
///   that yields unsolicited SSDP NOTIFY broadcasts (`alive`, `byebye`, `update`) on the
///   shared multicast group. Multiple concurrent consumers fan out from one underlying
///   listener, which tears down when the last consumer cancels.
///
/// `SSDPDiscovery` is an `actor` because it owns mutable lifecycle state (the shared
/// multicast listener handle, in-flight searches). Construction is cheap; consumers can
/// hold a single instance for the app's lifetime, or per-feature instances if desired.
///
/// ## Multicast entitlement (iOS / iPadOS / tvOS)
///
/// On iOS, iPadOS, and tvOS, joining the SSDP multicast group requires the
/// `com.apple.developer.networking.multicast` entitlement, which Apple gates behind a
/// manual application form. Without it, ``notifications()`` will throw
/// ``SSDPError/multicastEntitlementMissing``. macOS does not require it.
public actor SSDPDiscovery {

    /// SSDP multicast group address (`239.255.255.250`).
    public static let ssdpHost = SSDPMSearchRequest.ssdpHost
    /// SSDP multicast port (`1900`).
    public static let ssdpPort = SSDPMSearchRequest.ssdpPort

    private let transport: SSDPTransport

    /// Create a discovery using the default `Network.framework`-backed transport.
    public init() {
        self.transport = NetworkTransport()
    }

    /// Create a discovery with a custom transport (primarily for testing).
    init(transport: SSDPTransport) {
        self.transport = transport
    }

    // MARK: - M-SEARCH

    /// Convenience search by target. See ``search(_:timeout:)`` for full semantics.
    public nonisolated func search(
        for target: SSDPSearchTarget,
        maxWait: Int = 1,
        timeout: TimeInterval? = nil
    ) -> AsyncThrowingStream<SSDPMSearchResponse, Error> {
        let request = SSDPMSearchRequest(searchTarget: target, maxWait: maxWait)
        return search(request, timeout: timeout)
    }

    /// Send M-SEARCH broadcasts for `request` and yield matching responses.
    ///
    /// The library follows UPnP recommendations and retransmits the M-SEARCH at a stepped
    /// cadence (1s up to 5s elapsed → 3s up to 10s → 10s up to 60s → 60s thereafter) for
    /// reliability over UDP, especially on Wi-Fi.
    ///
    /// The stream finishes when:
    ///
    /// - `timeout` (if provided) elapses — stream finishes cleanly, even if zero responses.
    /// - The consumer breaks the `for try await` loop — stream and underlying socket end.
    /// - The transport fails — stream throws ``SSDPError/transportFailed(details:)``.
    public nonisolated func search(
        _ request: SSDPMSearchRequest,
        timeout: TimeInterval? = nil
    ) -> AsyncThrowingStream<SSDPMSearchResponse, Error> {
        let transport = self.transport
        return AsyncThrowingStream { continuation in
            // Box for child tasks so onTermination can cancel them. The supervisor task
            // populates these; onTermination — set up *before* the supervisor starts —
            // reads them on consumer cancel/finish.
            let children = TaskBox()

            continuation.onTermination = { @Sendable _ in
                Task { await children.cancelAll() }
            }

            let supervisor = Task {
                do {
                    let datagrams = try await transport.sendSearch(request)

                    // Retransmit task — preserves the original 1s/3s/10s/60s cadence.
                    let retransmitter = Task {
                        let start = ContinuousClock.now
                        while !Task.isCancelled {
                            let elapsed = ContinuousClock.now - start
                            let next: Duration
                            if elapsed < .seconds(5)        { next = .seconds(1) }
                            else if elapsed < .seconds(10)  { next = .seconds(3) }
                            else if elapsed < .seconds(60)  { next = .seconds(10) }
                            else                            { next = .seconds(60) }
                            try await Task.sleep(for: next)
                            if Task.isCancelled { break }
                            // The transport already sent the first M-SEARCH on connection ready;
                            // subsequent rounds open a fresh send to keep filling in for lost
                            // packets while the same receive socket continues to drain replies.
                            _ = try? await transport.sendSearch(request)
                        }
                    }

                    // Optional timeout task — finishes the consumer's stream cleanly when fired.
                    let timeoutTask: Task<Void, Never>? = timeout.map { seconds in
                        Task {
                            try? await Task.sleep(for: .seconds(seconds))
                            continuation.finish()
                        }
                    }

                    await children.set(retransmitter: retransmitter, timeoutTask: timeoutTask)

                    // Drain datagrams, parse, filter, yield.
                    for try await datagram in datagrams {
                        guard let raw = String(data: datagram.data, encoding: .utf8),
                              let message = SSDPMessageParser.parse(raw)
                        else {
                            SSDPLog.discovery.debug("Dropped unparseable M-SEARCH datagram from \(datagram.source, privacy: .public)")
                            continue
                        }
                        guard case .searchResponse(let response) = message else {
                            // Ignore stray NOTIFYs / requests on this stream.
                            continue
                        }
                        // Filter by search target — wildcard requests pass everything;
                        // specific requests pass only matching responses.
                        if request.searchTarget != .all && response.searchTarget != request.searchTarget {
                            continue
                        }
                        continuation.yield(response)
                    }

                    retransmitter.cancel()
                    timeoutTask?.cancel()
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            Task { await children.set(supervisor: supervisor) }
        }
    }

    // MARK: - NOTIFY

    /// Subscribe to unsolicited SSDP NOTIFY broadcasts.
    ///
    /// Returns a long-lived `AsyncThrowingStream` that yields ``SSDPNotification`` values
    /// (`alive` / `byebye` / `update`) for as long as the consumer iterates. Multiple
    /// concurrent calls share one underlying multicast group join; the join is
    /// reference-counted and tears down when the last consumer cancels.
    ///
    /// Throws ``SSDPError/multicastEntitlementMissing`` on iOS / iPadOS / tvOS if the
    /// host app lacks the required entitlement.
    public nonisolated func notifications() -> AsyncThrowingStream<SSDPNotification, Error> {
        let transport = self.transport
        return AsyncThrowingStream { continuation in
            let children = TaskBox()
            continuation.onTermination = { @Sendable _ in
                Task { await children.cancelAll() }
            }
            let supervisor = Task {
                do {
                    let datagrams = try await transport.multicastDatagrams()
                    for try await datagram in datagrams {
                        guard let raw = String(data: datagram.data, encoding: .utf8) else { continue }
                        guard case .notify(let n) = SSDPMessageParser.parse(raw) else {
                            // Ignore non-NOTIFY traffic on the multicast stream.
                            continue
                        }
                        continuation.yield(n)
                    }
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            Task { await children.set(supervisor: supervisor) }
        }
    }
}

// MARK: - Internal helpers

/// A small actor that accumulates the child Tasks spawned for a single search or
/// notification subscription and cancels them all on consumer teardown.
///
/// Reason for an actor (vs a `[Task]` captured directly): the supervisor is a
/// non-isolated `Task { ... }`, so we can't synchronously hand a reference to its
/// `retransmitter` / `timeoutTask` into the `onTermination` closure that's set up
/// *before* the supervisor starts. The actor is the synchronization point.
private actor TaskBox {
    private var supervisor: Task<Void, Never>?
    private var retransmitter: Task<Void, Error>?
    private var timeoutTask: Task<Void, Never>?

    func set(supervisor: Task<Void, Never>) {
        self.supervisor = supervisor
    }

    func set(retransmitter: Task<Void, Error>, timeoutTask: Task<Void, Never>?) {
        self.retransmitter = retransmitter
        self.timeoutTask = timeoutTask
    }

    func cancelAll() {
        supervisor?.cancel()
        retransmitter?.cancel()
        timeoutTask?.cancel()
    }
}

// MARK: - Convenience

public extension AsyncThrowingStream where Element == SSDPMSearchResponse, Failure == Error {

    /// Drain the stream into a deduplicated array.
    ///
    /// Convenience for the common "I just want a list of devices" pattern. Equality and
    /// hashing for ``SSDPMSearchResponse`` use `(usn, location)` so multiple responses
    /// from the same device collapse to one entry.
    ///
    /// The returned array is built in arrival order; later duplicates are dropped.
    func collect() async throws -> [SSDPMSearchResponse] {
        var seen: Set<SSDPMSearchResponse> = []
        var ordered: [SSDPMSearchResponse] = []
        for try await response in self {
            if seen.insert(response).inserted {
                ordered.append(response)
            }
        }
        return ordered
    }
}
