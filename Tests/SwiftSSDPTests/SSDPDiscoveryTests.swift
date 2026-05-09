//
//  SSDPDiscoveryTests.swift
//  SwiftSSDP
//
//  Copyright © 2017-2026 Paul Bates. All rights reserved.
//

import Foundation
import Testing
@testable import SwiftSSDP

@Suite("SSDPDiscovery — search")
struct SSDPDiscoverySearchTests {

    @Test("search yields parsed responses matching the request's target")
    func yieldsMatchingResponses() async throws {
        let mock = MockTransport()
        let discovery = SSDPDiscovery(transport: mock)

        let stream = discovery.search(for: .rootDevice, timeout: 0.5)

        // Subscribe first, then deliver.
        let task = Task { try await stream.collect() }
        try await waitForSearchSubscriber(in: mock)

        await mock.deliverSearchReply(try fixture("msearch-response-hue"))
        // Sonos response targets a ZonePlayer, not rootDevice — should be filtered out.
        await mock.deliverSearchReply(try fixture("msearch-response-sonos"))

        let collected = try await task.value
        #expect(collected.count == 1)
        #expect(collected.first?.location ==
            URL(string: "http://192.168.1.55:80/description.xml"))
    }

    @Test("search with .all passes through every response")
    func wildcardSearchPassesAll() async throws {
        let mock = MockTransport()
        let discovery = SSDPDiscovery(transport: mock)
        let stream = discovery.search(for: .all, timeout: 0.5)

        let task = Task { try await stream.collect() }
        try await waitForSearchSubscriber(in: mock)
        await mock.deliverSearchReply(try fixture("msearch-response-hue"))
        await mock.deliverSearchReply(try fixture("msearch-response-sonos"))

        let collected = try await task.value
        #expect(collected.count == 2)
    }

    @Test(".collect() deduplicates by (usn, location)")
    func collectDeduplicates() async throws {
        let mock = MockTransport()
        let discovery = SSDPDiscovery(transport: mock)
        let stream = discovery.search(for: .rootDevice, timeout: 0.5)

        let task = Task { try await stream.collect() }
        try await waitForSearchSubscriber(in: mock)

        let raw = try fixture("msearch-response-hue")
        await mock.deliverSearchReply(raw)
        await mock.deliverSearchReply(raw)
        await mock.deliverSearchReply(raw)

        let collected = try await task.value
        #expect(collected.count == 1)
    }

    @Test("Timeout finishes the stream cleanly without throwing")
    func timeoutFinishesCleanly() async throws {
        let mock = MockTransport()
        let discovery = SSDPDiscovery(transport: mock)
        let stream = discovery.search(for: .rootDevice, timeout: 0.2)
        // No deliveries — just wait for timeout.
        let result = try await stream.collect()
        #expect(result.isEmpty)
    }

    @Test("Transport send failure surfaces as a thrown error")
    func sendFailurePropagates() async throws {
        let mock = MockTransport()
        await mock.setSendFailure(.transportFailed(details: "primed failure"))
        let discovery = SSDPDiscovery(transport: mock)
        let stream = discovery.search(for: .rootDevice, timeout: 1)

        do {
            _ = try await stream.collect()
            Issue.record("Expected stream to throw")
        } catch let error as SSDPError {
            if case .transportFailed = error {} else {
                Issue.record("Expected .transportFailed, got \(error)")
            }
        }
    }

    @Test("Cancelling the consumer task tears down the underlying subscription")
    func cancellationTearsDownTransport() async throws {
        let mock = MockTransport()
        let discovery = SSDPDiscovery(transport: mock)

        let task = Task {
            for try await _ in discovery.search(for: .rootDevice) {
                // Iterate until cancelled.
            }
        }
        try await waitForSearchSubscriber(in: mock)
        #expect(await mock.searchSubscriberCount >= 1)

        task.cancel()
        try await waitFor { await mock.searchSubscriberCount == 0 }
        #expect(await mock.searchSubscriberCount == 0)
    }
}

@Suite("SSDPDiscovery — notifications")
struct SSDPDiscoveryNotificationTests {

    @Test("notifications() yields parsed alive/byebye/update events")
    func yieldsNotificationEvents() async throws {
        let mock = MockTransport()
        let discovery = SSDPDiscovery(transport: mock)

        let stream = discovery.notifications()
        let task = Task { () -> [SSDPNotification] in
            var collected: [SSDPNotification] = []
            for try await n in stream {
                collected.append(n)
                if collected.count == 3 { break }
            }
            return collected
        }
        try await waitForMulticastSubscriber(in: mock, count: 1)

        await mock.deliverNotify(try fixture("notify-alive-roku"))
        await mock.deliverNotify(try fixture("notify-byebye"))
        await mock.deliverNotify(try fixture("notify-update"))

        let events = try await task.value
        #expect(events.count == 3)
        if case .alive(let ad) = events[0] {
            #expect(ad.usn.contains("YR0070123456"))
        } else {
            Issue.record("Expected alive at index 0, got \(events[0])")
        }
        if case .byebye = events[1] {} else { Issue.record("Expected byebye at index 1") }
        if case .update = events[2] {} else { Issue.record("Expected update at index 2") }
    }

    @Test("Multiple consumers each receive every notification (fan-out)")
    func fansOutToMultipleConsumers() async throws {
        let mock = MockTransport()
        let discovery = SSDPDiscovery(transport: mock)

        let consumer1 = Task { () -> SSDPNotification? in
            for try await n in discovery.notifications() { return n }
            return nil
        }
        let consumer2 = Task { () -> SSDPNotification? in
            for try await n in discovery.notifications() { return n }
            return nil
        }

        try await waitForMulticastSubscriber(in: mock, count: 2)
        await mock.deliverNotify(try fixture("notify-alive-roku"))

        let n1 = try await consumer1.value
        let n2 = try await consumer2.value
        #expect(n1 != nil)
        #expect(n2 != nil)
        #expect(n1 == n2)
    }

    @Test("Multicast join failure is propagated as a thrown error")
    func multicastFailurePropagates() async throws {
        let mock = MockTransport()
        await mock.setMulticastFailure(.multicastEntitlementMissing)
        let discovery = SSDPDiscovery(transport: mock)

        do {
            for try await _ in discovery.notifications() {
                Issue.record("Should not yield")
            }
            Issue.record("Expected stream to throw")
        } catch let error as SSDPError {
            #expect(error == .multicastEntitlementMissing)
        }
    }
}

// MARK: - Helpers

/// Spin until predicate is true, with a short overall budget. Avoids fixed sleeps.
func waitFor(timeout: Duration = .seconds(2),
             _ predicate: @Sendable () async -> Bool) async throws
{
    let deadline = ContinuousClock.now + timeout
    while ContinuousClock.now < deadline {
        if await predicate() { return }
        try await Task.sleep(for: .milliseconds(5))
    }
    Issue.record("waitFor timed out")
}

func waitForSearchSubscriber(in mock: MockTransport, count: Int = 1) async throws {
    try await waitFor { await mock.searchSubscriberCount >= count }
}

func waitForMulticastSubscriber(in mock: MockTransport, count: Int = 1) async throws {
    try await waitFor { await mock.multicastSubscriberCount >= count }
}
