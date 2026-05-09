//
//  SSDPError.swift
//  SwiftSSDP
//
//  Copyright © 2017-2026 Paul Bates. All rights reserved.
//

import Foundation

/// Errors thrown by SwiftSSDP operations.
///
/// All cases are `Sendable` and `Equatable`. The underlying transport errors (typically
/// `NWError`) are stringified into the `details` payload because `NWError` is not
/// reliably `Sendable` or `Equatable` across SDK versions.
public enum SSDPError: Error, Sendable, Equatable {
    /// The underlying network transport failed (UDP send, connection setup, etc.).
    case transportFailed(details: String)

    /// Joining the SSDP multicast group (`239.255.255.250:1900`) failed.
    ///
    /// On iOS / iPadOS / tvOS, the most common cause is a missing
    /// `com.apple.developer.networking.multicast` entitlement — see
    /// ``SSDPError/multicastEntitlementMissing`` for a more specific signal.
    case multicastJoinFailed(details: String)

    /// The multicast entitlement (`com.apple.developer.networking.multicast`) is required
    /// on iOS / iPadOS / tvOS but is not present in the host app.
    ///
    /// Apple gates this entitlement behind a manual application form:
    /// <https://developer.apple.com/contact/request/networking-multicast>
    case multicastEntitlementMissing

    /// A wire-format SSDP message could not be parsed.
    case invalidResponse(reason: String)

    /// The configured timeout elapsed before any response arrived.
    ///
    /// Note: streams that simply complete because the timeout elapsed (and at least one
    /// response was delivered) finish cleanly — they do not throw `.timedOut`.
    case timedOut

    /// The operation was cancelled (typically because the consumer broke out of a
    /// `for try await` loop or the parent `Task` was cancelled).
    case cancelled
}
