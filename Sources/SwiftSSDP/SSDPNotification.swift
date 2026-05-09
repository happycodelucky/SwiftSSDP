//
//  SSDPNotification.swift
//  SwiftSSDP
//
//  Copyright © 2017-2026 Paul Bates. All rights reserved.
//

import Foundation

/// An unsolicited NOTIFY broadcast from a device on the local SSDP multicast group.
///
/// Emitted by ``SSDPDiscovery/notifications()``. Devices broadcast NOTIFY messages when
/// they join the network (`alive`), leave (`byebye`), or change their UPnP boot identity
/// (`update`, UPnP 1.1).
public enum SSDPNotification: Sendable, Hashable {
    /// `NTS: ssdp:alive` — device is reachable.
    case alive(SSDPAdvertisement)
    /// `NTS: ssdp:byebye` — device is leaving the network.
    ///
    /// `byebye` carries no `LOCATION` header (the device is going away, so there's
    /// nothing to fetch); the advertisement's `location` will be `nil`.
    case byebye(SSDPAdvertisement)
    /// `NTS: ssdp:update` — device's `BOOTID.UPNP.ORG` is changing (UPnP 1.1).
    case update(SSDPAdvertisement)

    /// The advertisement payload, regardless of which case.
    public var advertisement: SSDPAdvertisement {
        switch self {
        case .alive(let a), .byebye(let a), .update(let a):
            return a
        }
    }

    /// The notification target (`NT` header) for the announced device or service.
    public var notificationTarget: SSDPSearchTarget {
        advertisement.notificationTarget
    }
}

/// The data payload of a NOTIFY message.
///
/// Closely related to ``SSDPMSearchResponse`` but distinct — NOTIFY messages use `NT`
/// (Notification Target) where M-SEARCH responses use `ST` (Search Target), and NOTIFY
/// has no `EXT` header. ``location`` is optional because `byebye` notifications omit it.
public struct SSDPAdvertisement: Sendable, Hashable {
    /// `NT` — the notification target, identifying what kind of device/service is announcing.
    public let notificationTarget: SSDPSearchTarget

    /// `USN` — Unique Service Name.
    public let usn: String

    /// `LOCATION` — URL of the device description document.
    ///
    /// Always present in `alive` and `update`; absent in `byebye`.
    public let location: URL?

    /// `SERVER` — server identification string.
    public let server: String?

    /// `CACHE-CONTROL: max-age=<seconds>` — validity duration in seconds. `nil` if absent.
    public let cacheControl: TimeInterval?

    /// `BOOTID.UPNP.ORG` — UPnP 1.1 boot identifier.
    public let bootID: Int?

    /// `CONFIGID.UPNP.ORG` — UPnP 1.1 configuration identifier.
    public let configID: Int?

    /// `NEXTBOOTID.UPNP.ORG` — UPnP 1.1, present only on `ssdp:update`.
    public let nextBootID: Int?

    /// All headers not surfaced as typed properties above.
    public let otherHeaders: SSDPHeaders

    public init(
        notificationTarget: SSDPSearchTarget,
        usn: String,
        location: URL?,
        server: String?,
        cacheControl: TimeInterval?,
        bootID: Int?,
        configID: Int?,
        nextBootID: Int?,
        otherHeaders: SSDPHeaders
    ) {
        self.notificationTarget = notificationTarget
        self.usn = usn
        self.location = location
        self.server = server
        self.cacheControl = cacheControl
        self.bootID = bootID
        self.configID = configID
        self.nextBootID = nextBootID
        self.otherHeaders = otherHeaders
    }

    /// `Hashable` conformance via the natural deduplication key (`usn` + `notificationTarget`).
    public func hash(into hasher: inout Hasher) {
        hasher.combine(usn)
        hasher.combine(notificationTarget)
    }

    public static func == (lhs: SSDPAdvertisement, rhs: SSDPAdvertisement) -> Bool {
        lhs.usn == rhs.usn && lhs.notificationTarget == rhs.notificationTarget
    }
}
