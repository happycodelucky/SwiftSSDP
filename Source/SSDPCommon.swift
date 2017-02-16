//
//  SSDPCommon.swift
//  SwiftSSDP
//
//  Created by Paul Bates on 2/6/17.
//  Copyright © 2017 Paul Bates. All rights reserved.
//

import Foundation

/// Category used for logging SSDP logs
public let loggerDiscoveryCategory = "SSDP"

/// SSDP M-Search, Notify, and Response header keys
struct SSDPHeaderKeys {
    static let cacheControl: String = "CACHE-CONTROL"
    static let date: String = "DATE"
    static let ext: String = "EXT"
    static let host: String = "HOST"
    static let location: String = "LOCATION"
    static let man: String = "MAN"
    static let maxWait: String = "MX"
    static let notifyType: String = "NT"
    static let notifySubType: String = "NTS"
    static let searchTarget: String = "ST"
    static let server: String = "SERVER"
    static let usn: String = "USN"
}

/// SSDP headers
public typealias SSDPHeaders = [String: String]

/// SSDP message announcement type
public enum SSDPMessageAnnoucement: String {
    /// For M-SEARCH requests, used as MAN value
    case discover = "ssdp:discover"
    /// For NOTIFY Alive multicast broadcasts, used in NTS
    case alive = "ssdp:alive"
    /// For NOTIFY ByeBye multicast broadcasts, used in NTS
    case byeBye = "ssdp:byebye"
}
