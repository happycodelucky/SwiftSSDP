//
//  SSDPMessage.swift
//  SwiftSSDP
//
//  Created by Paul Bates on 2/4/17.
//  Copyright © 2017 Paul Bates. All rights reserved.
//

import Foundation

/// M-SEARCH request to peform a device discovery on the local area network for UPnP devices
public struct SSDPMSearchRequest {
    public static let messsageHeader: String = "M-SEARCH * HTTP/1.1"
    
    /// Delegate to call discovery on
    public let delegate: SSDPDiscoveryDelegate
    /// `MAN` type
    public let man: SSDPMessageAnnoucement = .discover
    /// `MX` max wait time
    public let maxWaitTime: Int
    /// `ST` search target for M-SEARCH
    public let searchTarget: SSDPSearchTarget
    /// Any addition headers to include in the M-SEARCH request not standardized by UPnP
    public let otherHeaders: SSDPHeaders?
    /// M-SEARCH request message as `String`
    public var message: String {
        var headers: SSDPHeaders = [
            SSDPHeaderKeys.host: "\(SSDPDiscovery.ssdpHost):\(SSDPDiscovery.ssdpPort)",
            SSDPHeaderKeys.man: self.man.rawValue,
            SSDPHeaderKeys.maxWait: self.maxWaitTime.description,
            SSDPHeaderKeys.searchTarget: self.searchTarget.description
        ]
        if let otherHeaders = self.otherHeaders {
            for (key, value) in otherHeaders {
                if headers.index(forKey: key) == nil {
                    headers[key] = value
                }
            }
        }
        var message: String = SSDPMSearchRequest.messsageHeader + "\r\n"
        for (key, value) in headers {
            message.append("\(key): \(value)\r\n")
        }
        return message
    }

    //
    // MARK: Initialization
    //
    
    ///
    ///
    public init(delegate: SSDPDiscoveryDelegate, searchTarget: SSDPSearchTarget, maxWait: Int = 1, otherHeaders: SSDPHeaders? = nil) {
        self.delegate = delegate
        self.searchTarget = searchTarget
        self.maxWaitTime = maxWait
        self.otherHeaders = otherHeaders
    }
}

//
// MARK: -
//

// SSDPMSearchRequest: CustomStringConvertible
extension SSDPMSearchRequest: CustomStringConvertible {
    public var description: String {
        return self.message
    }
}
