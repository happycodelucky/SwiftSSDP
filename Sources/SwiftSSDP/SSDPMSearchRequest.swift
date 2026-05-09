//
//  SSDPMSearchRequest.swift
//  SwiftSSDP
//
//  Copyright © 2017-2026 Paul Bates. All rights reserved.
//

import Foundation

/// An SSDP M-SEARCH request describing what to discover on the local network.
///
/// Used as the input to ``SSDPDiscovery/search(_:timeout:)``. For common cases prefer the
/// convenience overload ``SSDPDiscovery/search(for:maxWait:timeout:)``.
public struct SSDPMSearchRequest: Sendable, Equatable {
    /// The leading request line (`M-SEARCH * HTTP/1.1`).
    public static let messageHeader = "M-SEARCH * HTTP/1.1"

    /// SSDP multicast group address.
    static let ssdpHost = "239.255.255.250"
    /// SSDP multicast port.
    static let ssdpPort = 1900

    /// `ST` — what to search for.
    public let searchTarget: SSDPSearchTarget
    /// `MX` — maximum response wait time in seconds, advertised to responders.
    ///
    /// Devices choose a random delay in `[0, MX]` before replying, to avoid response storms.
    /// Per UPnP recommendations this should be in the 1–5 second range. Default 1.
    public let maxWaitTime: Int
    /// Additional non-standard headers to include in the request.
    ///
    /// Standard headers (`HOST`, `MAN`, `MX`, `ST`) take precedence — values supplied here
    /// for those keys are ignored.
    public let otherHeaders: SSDPHeaders

    /// Build a request from explicit parameters.
    public init(
        searchTarget: SSDPSearchTarget,
        maxWait: Int = 1,
        otherHeaders: SSDPHeaders = [:]
    ) {
        self.searchTarget = searchTarget
        self.maxWaitTime = maxWait
        self.otherHeaders = otherHeaders
    }

    /// The fully serialized M-SEARCH wire message.
    ///
    /// Headers are emitted in deterministic (alphabetical) order so the output is testable.
    /// UPnP does not require any particular header ordering.
    public var message: String {
        // Standard headers always come from the request; consumer-supplied otherHeaders
        // can only contribute non-standard keys.
        var headers: [String: String] = [
            SSDPHeaderKeys.host: "\(Self.ssdpHost):\(Self.ssdpPort)",
            SSDPHeaderKeys.man: "\"\(SSDPMessageAnnouncement.discover.rawValue)\"",
            SSDPHeaderKeys.maxWait: String(maxWaitTime),
            SSDPHeaderKeys.searchTarget: searchTarget.rawValue,
        ]
        for (k, v) in otherHeaders.asDictionary where headers[k] == nil {
            headers[k] = v
        }

        var lines: [String] = [Self.messageHeader]
        for key in headers.keys.sorted() {
            lines.append("\(key): \(headers[key]!)")
        }
        // SSDP messages terminate with CRLF and a final blank line.
        return lines.joined(separator: "\r\n") + "\r\n\r\n"
    }
}

extension SSDPMSearchRequest: CustomStringConvertible {
    public var description: String { message }
}
