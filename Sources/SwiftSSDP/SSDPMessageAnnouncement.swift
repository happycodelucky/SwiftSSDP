//
//  SSDPMessageAnnouncement.swift
//  SwiftSSDP
//
//  Copyright © 2017-2026 Paul Bates. All rights reserved.
//

import Foundation

/// SSDP announcement type used in `MAN` (M-SEARCH) and `NTS` (NOTIFY) headers.
///
/// - Note: This type was previously misspelled `SSDPMessageAnnoucement` (missing 'n').
///   The corrected name is the only one available in v2.0+.
public enum SSDPMessageAnnouncement: String, Sendable, Equatable {
    /// `MAN: "ssdp:discover"` — used in M-SEARCH requests.
    case discover = "ssdp:discover"
    /// `NTS: ssdp:alive` — device or service is now reachable.
    case alive = "ssdp:alive"
    /// `NTS: ssdp:byebye` — device or service is leaving the network.
    case byeBye = "ssdp:byebye"
    /// `NTS: ssdp:update` (UPnP 1.1) — device's BOOTID is changing.
    case update = "ssdp:update"
}
