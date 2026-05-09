//
//  SSDPMSearchResponse.swift
//  SwiftSSDP
//
//  Copyright © 2017-2026 Paul Bates. All rights reserved.
//

import Foundation

/// A parsed response to an M-SEARCH request, describing one discovered device or service.
///
/// Two responses are considered equal (and produce the same hash) when they share the same
/// `usn` and `location` — the natural deduplication key for SSDP.
public struct SSDPMSearchResponse: Sendable, Hashable {
    /// `CACHE-CONTROL: max-age=<seconds>` — how long the response is valid for.
    ///
    /// In v2.0 this is the raw `max-age` in seconds (a `TimeInterval`). The previous
    /// release exposed this as a `Date` computed at parse time, which silently became
    /// stale in long-running listeners. Consumers should compute their own expiration
    /// instant if they need wall-clock semantics.
    public let cacheControl: TimeInterval?

    /// `DATE` — the wall-clock instant at which the responder generated the message.
    ///
    /// Parsed as RFC 1123 (`EEE, dd MMM yyyy HH:mm:ss zzz`). Many devices omit this
    /// header or send it in non-standard formats; expect `nil` to be common.
    public let date: Date?

    /// `EXT` — a presence-only header required by UPnP 1.0.
    ///
    /// Note: real-world devices (notably some Hue and Roku firmware) omit `EXT`. The
    /// parser is lenient — `ext == false` indicates the header was absent.
    public let ext: Bool

    /// `LOCATION` — URL of the device's description document.
    public let location: URL

    /// `SERVER` — server identification string, e.g. `Linux/3.14 UPnP/1.0 Sonos/12.3.1`.
    public let server: String?

    /// `ST` — search target the responder is matching.
    public let searchTarget: SSDPSearchTarget

    /// `USN` — Unique Service Name, a globally unique device/service identifier.
    public let usn: String

    /// All headers from the response that are not surfaced as a typed property above.
    ///
    /// This includes UPnP 1.1 fields (`BOOTID.UPNP.ORG`, `CONFIGID.UPNP.ORG`,
    /// `SEARCHPORT.UPNP.ORG`, `SECURELOCATION.UPNP.ORG`) when present.
    public let otherHeaders: SSDPHeaders

    /// Designated initializer — primarily for parser use, but public for advanced clients
    /// that want to construct synthetic responses (in tests or fixtures).
    public init(
        cacheControl: TimeInterval?,
        date: Date?,
        ext: Bool,
        location: URL,
        server: String?,
        searchTarget: SSDPSearchTarget,
        usn: String,
        otherHeaders: SSDPHeaders
    ) {
        self.cacheControl = cacheControl
        self.date = date
        self.ext = ext
        self.location = location
        self.server = server
        self.searchTarget = searchTarget
        self.usn = usn
        self.otherHeaders = otherHeaders
    }

    // MARK: - Hashable

    public func hash(into hasher: inout Hasher) {
        hasher.combine(usn)
        hasher.combine(location)
    }

    public static func == (lhs: SSDPMSearchResponse, rhs: SSDPMSearchResponse) -> Bool {
        lhs.usn == rhs.usn && lhs.location == rhs.location
    }
}
