//
//  SSDPMessageScanner.swift
//  SwiftSSDP
//
//  Created by Paul Bates on 2/7/17.
//  Copyright © 2017 Paul Bates. All rights reserved.
//

import Foundation

/// Types of responses from discovery or from joining the SSDP multicast group
public enum SSDPMessage {
    /// A M-SEARCH request broadcast
    case searchRequest
    /// A M-SEARCH response for a discovered device or service
    case searchResponse(response: SSDPMSearchResponse)
    /// A NOTIFY broadcast
    case notify
}

//
// MARK: -
//

/// Parses M-SEARCH and NOTIFY responses from M-SEARCH broadcasts or NOTIFY multicasts on the local area network
class SSDPMessageParser {

    /// Parses an M-SEARCH request/response or a multicast NOTIFY broadcast
    /// Note: NOTIFY currently not supported
    ///
    /// - Parameters:
    ///     - response: Full response to parse
    public static func parse(response: String) -> SSDPMessage? {
        if response.isEmpty {
            return nil
        }
        
        let scanner = Scanner(string: response)
        scanner.charactersToBeSkipped = CharacterSet.newlines
        
        // Scan first token to ensure we have an expected response
        guard let token = scanInitialToken(scanner: scanner) else {
            return nil
        }
        
        // Scan remaining headers to construct and init a response from
        var headers: [String: String] = [:]
        while(!scanner.isAtEnd) {
            if let pair = scanKeyValuePair(scanner: scanner) {
                headers[pair.key] = pair.value
            }
        }
        
        return constructMessage(token: token, headers: headers)
    }
    
    //
    // MARK: Private Functions
    //
    
    /// Scans an initial token from the response to determine what the response type is
    ///
    /// - Parameters:
    ///     - scanner: Scanner to scan an initial token from
    ///
    /// - Returns: An initial token or nil if the scanner has already reached the end
    private static func scanInitialToken(scanner: Scanner) -> String? {
        if scanner.isAtEnd {
            return nil
        }
        
        var buffer: NSString? = nil
        if scanner.scanUpToCharacters(from: CharacterSet.whitespacesAndNewlines, into: &buffer) {
            // Scan to the end of the line
            _ = scanLine(scanner: scanner)
            
            return buffer as String?
        }
        
        return nil
    }
    
    /// Scans a single line from the response
    ///
    /// - Parameters:
    ///     - scanner: Scanner to scan the next line from
    ///
    /// - Returns: An entire line or nil if the scanner has already reached the end
    private static func scanLine(scanner: Scanner) -> String? {
        if scanner.isAtEnd {
            return nil
        }
        
        var buffer: NSString? = nil
        if scanner.scanUpToCharacters(from: CharacterSet.newlines, into: &buffer) {
            return buffer as String?
        }
        
        return nil
    }
    
    /// Scans a single line's key/value pair in the form of "KEY: value"
    ///
    /// - Parameters:
    ///     - scanner: Scanner to scan the pair from
    ///
    /// - Returns: A tuple of the key/value pair or nil if no match could be found or the scanner has reached the end
    private static func scanKeyValuePair(scanner: Scanner) -> (key: String, value: String)? {
        if scanner.isAtEnd {
            return nil
        }
        
        var buffer: NSString? = nil
        let delimiterSet = CharacterSet(charactersIn: ":").union(CharacterSet.whitespaces)
        if scanner.scanUpToCharacters(from: delimiterSet, into: &buffer), let key = buffer as String? {
            if scanner.scanCharacters(from: delimiterSet, into: nil) && !scanner.isAtEnd {
                if CharacterSet.newlines.contains(UnicodeScalar((scanner.string as NSString).character(at: scanner.scanLocation))!) {
                    return (key: key, value: "")
                } else if let value = scanLine(scanner: scanner) {
                    return (key: key, value: value.trimmingCharacters(in: CharacterSet.whitespaces))
                } else {
                    return nil
                }
            }
        }
        
        return nil
    }
    
    /// Constructs a message based on initial token of the raw response and the parsed headers.
    ///
    /// - Parameters
    ///     - token: Initial token parses from the response
    ///     - headers: Parsed dictionary of headers to construct a response with
    ///
    /// - Returns: A fully formed message
    private static func constructMessage(token: String, headers: [String: String]) -> SSDPMessage? {
        if token == "M-SEARCH" {
            return nil
        } else if token == "NOTIFY" {
            return nil
        } else if token == "HTTP/1.1" {
            guard let response = SSDPMSearchResponse(fromHeaders: headers) else {
                return nil
            }
            return .searchResponse(response: response)
        }
        
        return nil
    }
    
}

//
// MARK: -
//

// Extension to support initializing an `SSDPMSearchResponse` from `SSDPMessageParser` parsed message
extension SSDPMSearchResponse {
    
    /// Attempts to initialize a `SSDPMSearchResponse` from parsed response headers. If critical headers are missing or malformed the 
    /// response will not be initialized
    ///
    /// - Parameters:
    ///     - fromHeaders: M-SEARCH response headers
    init?(fromHeaders headers: [String: String]) {
        var mutableHeaders = headers
        
        // CACHE-CONTROL
        if let cacheControlString = headers[SSDPHeaderKeys.cacheControl] {
            let maxAgeRegEx = try! NSRegularExpression(pattern: "max\\-age[ \t]*=[ \t]*([0-9]+)")
            var matches: [String] = []
            for match in maxAgeRegEx.matches(in: cacheControlString, range: NSRange(location:0, length: cacheControlString.utf8.count)) {
                let capturedRange = match.range(at: 1)
                if !NSEqualRanges(capturedRange, NSMakeRange(NSNotFound, 0)) {
                    let theResult = (cacheControlString as NSString).substring(with: capturedRange)
                    matches.append(theResult)
                }
            }
            if matches.count > 0, let maxAgeSeconds = Int(matches[0], radix: 10) {
                self.cacheControl = Date(timeIntervalSinceNow: TimeInterval(maxAgeSeconds) * 1000.0)
                mutableHeaders.removeValue(forKey: SSDPHeaderKeys.cacheControl)
            } else {
                self.cacheControl = nil
            }
        } else {
            self.cacheControl = nil
        }
        
        // DATE
        if let dateString = headers[SSDPHeaderKeys.date], let date = DateFormatter().date(from: dateString) {
            self.date = date
            mutableHeaders.removeValue(forKey: SSDPHeaderKeys.date)
        } else {
            self.date = nil
        }
        
        // EXT
        guard let _ = headers[SSDPHeaderKeys.ext] else {
            return nil
        }
        self.ext = true
        mutableHeaders.removeValue(forKey: SSDPHeaderKeys.ext)
        
        // LOCATION
        guard let location = headers[SSDPHeaderKeys.location], let locationUrl = URL(string: location) else {
            return nil
        }
        self.location = locationUrl
        mutableHeaders.removeValue(forKey: SSDPHeaderKeys.location)
        
        // SERVER
        if let server = headers[SSDPHeaderKeys.server] {
            self.server = server
            mutableHeaders.removeValue(forKey: SSDPHeaderKeys.server)
        } else {
            self.server = nil
        }
        
        // ST
        guard let searchTargetString = headers[SSDPHeaderKeys.searchTarget], let searchTarget = SSDPSearchTarget(rawValue: searchTargetString) else {
            return nil
        }
        self.searchTarget = searchTarget
        mutableHeaders.removeValue(forKey: SSDPHeaderKeys.searchTarget)
        
        // USN
        guard let usn = headers[SSDPHeaderKeys.usn] else {
            return nil
        }
        self.usn = usn
        mutableHeaders.removeValue(forKey: SSDPHeaderKeys.usn)
        
        self.otherHeaders = mutableHeaders
    }
}
