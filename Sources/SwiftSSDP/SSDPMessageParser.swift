//
//  SSDPMessageParser.swift
//  SwiftSSDP
//
//  Copyright © 2017-2026 Paul Bates. All rights reserved.
//

import Foundation

/// A typed wire-format SSDP message.
///
/// SSDP messages share an HTTP/1.1-like syntax (request line + headers + blank line) but
/// fall into three distinct families:
public enum SSDPMessage: Sendable {
    /// An M-SEARCH request observed on the multicast group (uncommon for clients to receive).
    case searchRequest
    /// A unicast response to an M-SEARCH (`HTTP/1.1 200 OK`).
    case searchResponse(SSDPMSearchResponse)
    /// A NOTIFY broadcast — `alive`, `byebye`, or `update`.
    case notify(SSDPNotification)
}

/// Parses raw SSDP wire bytes into typed ``SSDPMessage`` values.
///
/// Lenient by design: real-world devices don't all follow the spec strictly. Missing
/// non-critical headers (`EXT`, `SERVER`, `DATE`, `CACHE-CONTROL`) are tolerated; only the
/// genuinely required ones (`LOCATION`/`ST`/`USN` for responses; `NT`/`NTS`/`USN` for
/// NOTIFY, with `LOCATION` additionally required for `alive`/`update`) cause a `nil` return.
enum SSDPMessageParser {

    /// Parse a UTF-8 string of an SSDP message.
    ///
    /// Returns `nil` if the message can't be recognized. Returns `.searchRequest` for an
    /// observed M-SEARCH (we have no use for these yet but they're surfaced for completeness).
    static func parse(_ raw: String) -> SSDPMessage? {
        guard !raw.isEmpty else { return nil }

        // First non-empty line is the request/status line.
        var lines = raw.split(whereSeparator: \.isNewline).makeIterator()
        guard let firstLine = lines.next() else { return nil }
        let firstTokens = firstLine.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        guard let token = firstTokens.first else { return nil }
        let leading = String(token).uppercased()

        // Collect headers from the remaining lines.
        var headers = SSDPHeaders()
        for line in lines {
            // Headers continue until a blank line; once headers are done the rest is ignored.
            if line.isEmpty { break }
            guard let colon = line.firstIndex(of: ":") else { continue }
            let key = String(line[..<colon]).trimmingCharacters(in: .whitespaces)
            let value = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
            guard !key.isEmpty else { continue }
            headers[key] = value
        }

        switch leading {
        case "HTTP/1.1":
            // M-SEARCH response.
            guard let response = makeSearchResponse(from: headers) else { return nil }
            return .searchResponse(response)

        case "NOTIFY":
            guard let notification = makeNotification(from: headers) else { return nil }
            return .notify(notification)

        case "M-SEARCH":
            return .searchRequest

        default:
            return nil
        }
    }

    // MARK: - SSDPMSearchResponse construction

    private static func makeSearchResponse(from headers: SSDPHeaders) -> SSDPMSearchResponse? {
        // Required: LOCATION, ST, USN.
        guard let locationString = headers[SSDPHeaderKeys.location],
              let location = URL(string: locationString)
        else { return nil }
        guard let stString = headers[SSDPHeaderKeys.searchTarget],
              let st = SSDPSearchTarget(rawValue: stString)
        else { return nil }
        guard let usn = headers[SSDPHeaderKeys.usn] else { return nil }

        let cacheControl = parseCacheControl(headers[SSDPHeaderKeys.cacheControl])
        let date = parseDate(headers[SSDPHeaderKeys.date])
        // EXT is required by spec but omitted by Hue bridges and some Roku firmware. Lenient.
        let ext = headers[SSDPHeaderKeys.ext] != nil
        let server = headers[SSDPHeaderKeys.server]

        let consumed = [
            SSDPHeaderKeys.cacheControl,
            SSDPHeaderKeys.date,
            SSDPHeaderKeys.ext,
            SSDPHeaderKeys.location,
            SSDPHeaderKeys.searchTarget,
            SSDPHeaderKeys.server,
            SSDPHeaderKeys.usn,
        ]
        let other = headers.removing(consumed)

        return SSDPMSearchResponse(
            cacheControl: cacheControl,
            date: date,
            ext: ext,
            location: location,
            server: server,
            searchTarget: st,
            usn: usn,
            otherHeaders: other
        )
    }

    // MARK: - SSDPNotification construction

    private static func makeNotification(from headers: SSDPHeaders) -> SSDPNotification? {
        // Required for all NOTIFYs: NT, NTS, USN.
        guard let ntString = headers[SSDPHeaderKeys.notifyType],
              let nt = SSDPSearchTarget(rawValue: ntString)
        else { return nil }
        guard let ntsString = headers[SSDPHeaderKeys.notifySubType],
              let nts = SSDPMessageAnnouncement(rawValue: ntsString.lowercased())
        else { return nil }
        guard let usn = headers[SSDPHeaderKeys.usn] else { return nil }

        let cacheControl = parseCacheControl(headers[SSDPHeaderKeys.cacheControl])
        let server = headers[SSDPHeaderKeys.server]
        let bootID = headers[SSDPHeaderKeys.bootID].flatMap { Int($0) }
        let configID = headers[SSDPHeaderKeys.configID].flatMap { Int($0) }
        let nextBootID = headers[SSDPHeaderKeys.nextBootID].flatMap { Int($0) }

        // LOCATION is required for alive/update; absent for byebye.
        let location: URL?
        switch nts {
        case .alive, .update:
            guard let s = headers[SSDPHeaderKeys.location], let u = URL(string: s) else {
                return nil
            }
            location = u
        case .byeBye:
            location = headers[SSDPHeaderKeys.location].flatMap { URL(string: $0) }
        case .discover:
            // ssdp:discover is not a valid NTS — defensive only.
            return nil
        }

        let consumed = [
            SSDPHeaderKeys.cacheControl,
            SSDPHeaderKeys.location,
            SSDPHeaderKeys.notifyType,
            SSDPHeaderKeys.notifySubType,
            SSDPHeaderKeys.server,
            SSDPHeaderKeys.usn,
            SSDPHeaderKeys.bootID,
            SSDPHeaderKeys.configID,
            SSDPHeaderKeys.nextBootID,
        ]
        let other = headers.removing(consumed)

        let advertisement = SSDPAdvertisement(
            notificationTarget: nt,
            usn: usn,
            location: location,
            server: server,
            cacheControl: cacheControl,
            bootID: bootID,
            configID: configID,
            nextBootID: nextBootID,
            otherHeaders: other
        )

        switch nts {
        case .alive: return .alive(advertisement)
        case .byeBye: return .byebye(advertisement)
        case .update: return .update(advertisement)
        case .discover: return nil
        }
    }

    // MARK: - Header value parsing

    /// Parses a `CACHE-CONTROL` value, extracting the `max-age` directive.
    ///
    /// Returns the raw `max-age` in seconds (a `TimeInterval`). The pre-v2.0 release of
    /// this library multiplied this value by 1000.0 — a 1000× error that has been here
    /// since 2017. v2.0 returns the correct seconds value.
    private static func parseCacheControl(_ value: String?) -> TimeInterval? {
        guard let value else { return nil }
        // CACHE-CONTROL can carry multiple directives separated by commas, e.g.
        // "max-age=1800, no-cache". We only care about max-age.
        for directive in value.split(separator: ",") {
            let trimmed = directive.trimmingCharacters(in: .whitespaces)
            let parts = trimmed.split(separator: "=", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let key = parts[0].trimmingCharacters(in: .whitespaces).lowercased()
            let raw = parts[1].trimmingCharacters(in: .whitespaces)
            guard key == "max-age", let seconds = Int(raw) else { continue }
            return TimeInterval(seconds)
        }
        return nil
    }

    /// RFC 1123 date formatter for SSDP `DATE` headers.
    ///
    /// The pre-v2.0 release used `DateFormatter()` with no format set, so the parse always
    /// returned `nil`. v2.0 uses the correct RFC 1123 format with a POSIX locale (per
    /// Apple's TN1480 — required to prevent the user's locale from breaking parsing).
    private static let rfc1123Formatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "GMT")
        f.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        return f
    }()

    private static func parseDate(_ value: String?) -> Date? {
        guard let value else { return nil }
        return rfc1123Formatter.date(from: value)
    }
}
