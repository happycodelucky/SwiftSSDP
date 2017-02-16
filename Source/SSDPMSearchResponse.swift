//
//  SSDPMSearchResponse.swift
//  SwiftSSDP
//
//  Created by Paul Bates on 2/8/17.
//  Copyright © 2017 Paul Bates. All rights reserved.
//

import Foundation

/// An M-SEARCH response for a device or service found during device/service discovery
public struct SSDPMSearchResponse {
    /// CACHE-CONTROL
    public let cacheControl: Date?
    /// DATE
    public let date: Date?
    /// EXT
    public let ext: Bool
    /// LOCATION
    public let location: URL
    /// SERVER
    public let server: String?
    /// ST
    public let searchTarget: SSDPSearchTarget
    /// USN
    public let usn: String
    
    /// All other headers in the discovery response
    public let otherHeaders: [String: String]
}

//
// MARK: -
//

extension SSDPMSearchResponse: Hashable {
    public var hashValue: Int {
        return (31 &* self.usn.hashValue) &+ self.location.hashValue
    }
}

public func ==(lhs: SSDPMSearchResponse, rhs: SSDPMSearchResponse) -> Bool {
    return lhs.usn == rhs.usn && lhs.location == rhs.location
}
