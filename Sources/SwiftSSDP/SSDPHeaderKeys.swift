//
//  SSDPHeaderKeys.swift
//  SwiftSSDP
//
//  Copyright © 2017-2026 Paul Bates. All rights reserved.
//

import Foundation

/// SSDP header key constants used in M-SEARCH, NOTIFY, and search-response messages.
///
/// Header names in the SSDP wire format are case-insensitive. These constants use the
/// canonical UPnP-1.0 / UPnP-1.1 capitalization for outbound serialization.
enum SSDPHeaderKeys {
    // RFC 2616 / UPnP 1.0
    static let cacheControl = "CACHE-CONTROL"
    static let date = "DATE"
    static let ext = "EXT"
    static let host = "HOST"
    static let location = "LOCATION"
    static let man = "MAN"
    static let maxWait = "MX"
    static let notifyType = "NT"
    static let notifySubType = "NTS"
    static let searchTarget = "ST"
    static let server = "SERVER"
    static let usn = "USN"

    // UPnP 1.1 additions
    static let bootID = "BOOTID.UPNP.ORG"
    static let configID = "CONFIGID.UPNP.ORG"
    static let searchPort = "SEARCHPORT.UPNP.ORG"
    static let secureLocation = "SECURELOCATION.UPNP.ORG"
    static let nextBootID = "NEXTBOOTID.UPNP.ORG"
}
