//
//  SSDPMessageParserTests.swift
//  SwiftSSDP
//
//  Copyright © 2017-2026 Paul Bates. All rights reserved.
//

import Foundation
import Testing
@testable import SwiftSSDP

@Suite("SSDPMessageParser — M-SEARCH responses")
struct SSDPMessageParserSearchResponseTests {

    @Test("Sonos M-SEARCH response parses all canonical fields")
    func parsesSonosResponse() throws {
        let raw = try fixture("msearch-response-sonos")
        let message = try #require(SSDPMessageParser.parse(raw))
        guard case .searchResponse(let response) = message else {
            Issue.record("Expected .searchResponse, got \(message)")
            return
        }

        #expect(response.location == URL(string:
            "http://192.168.1.42:1400/xml/device_description.xml"))
        #expect(response.usn ==
            "uuid:RINCON_000E58A1B2C300400::urn:schemas-upnp-org:device:ZonePlayer:1")
        #expect(response.searchTarget ==
            .deviceType(schema: "schemas-upnp-org", deviceType: "ZonePlayer", version: 1))
        #expect(response.server == "Linux UPnP/1.0 Sonos/76.1-37220 (ZP120)")
        #expect(response.ext == true)
        // CACHE-CONTROL bug regression: pre-v2.0 multiplied by 1000.
        // Sonos sends "max-age = 1800"; we must surface 1800 seconds, not 1_800_000.
        #expect(response.cacheControl == 1800)
        // DATE bug regression: pre-v2.0 used DateFormatter() with no format and always returned nil.
        // RFC 1123: "Sun, 06 Nov 1994 08:49:37 GMT"
        let expectedDate = DateComponents(
            calendar: Calendar(identifier: .gregorian),
            timeZone: TimeZone(identifier: "GMT"),
            year: 1994, month: 11, day: 6,
            hour: 8, minute: 49, second: 37
        ).date
        #expect(response.date == expectedDate)
        // Vendor headers preserved in otherHeaders.
        #expect(response.otherHeaders["X-RINCON-HOUSEHOLD"] == "Sonos_household_1")
        #expect(response.otherHeaders["X-RINCON-BOOTSEQ"] == "23")
    }

    @Test("Hue bridge M-SEARCH response parses without EXT (lenient mode)")
    func parsesHueWithoutExt() throws {
        let raw = try fixture("msearch-response-hue")
        let message = try #require(SSDPMessageParser.parse(raw))
        guard case .searchResponse(let response) = message else {
            Issue.record("Expected .searchResponse, got \(message)")
            return
        }
        #expect(response.searchTarget == .rootDevice)
        #expect(response.cacheControl == 100)
        #expect(response.ext == false)        // Hue omits EXT — must not reject
        #expect(response.otherHeaders["hue-bridgeid"] == "001788FFFE112233")
    }

    @Test("Malformed response missing EXT still parses")
    func parsesMalformedMissingExt() throws {
        let raw = try fixture("malformed-missing-ext")
        let message = try #require(SSDPMessageParser.parse(raw))
        guard case .searchResponse(let response) = message else {
            Issue.record("Expected .searchResponse")
            return
        }
        #expect(response.ext == false)
    }

    @Test("Response missing required headers returns nil")
    func rejectsMissingRequired() {
        let noLocation = """
            HTTP/1.1 200 OK\r
            ST: upnp:rootdevice\r
            USN: uuid:foo\r
            \r

            """
        #expect(SSDPMessageParser.parse(noLocation) == nil)

        let noUSN = """
            HTTP/1.1 200 OK\r
            LOCATION: http://example.com/desc.xml\r
            ST: upnp:rootdevice\r
            \r

            """
        #expect(SSDPMessageParser.parse(noUSN) == nil)
    }

    @Test("Empty input returns nil")
    func rejectsEmpty() {
        #expect(SSDPMessageParser.parse("") == nil)
    }

    // MARK: - Cache-Control directive parsing

    @Test("CACHE-CONTROL accepts whitespace and multiple directives")
    func cacheControlMultipleDirectives() throws {
        // "max-age = 1800, no-cache" — Sonos sends spaces around the =.
        let raw = """
            HTTP/1.1 200 OK\r
            CACHE-CONTROL: max-age = 1800 , no-cache\r
            EXT:\r
            LOCATION: http://example.com/d.xml\r
            ST: upnp:rootdevice\r
            USN: uuid:test\r
            \r

            """
        guard case .searchResponse(let response) = try #require(SSDPMessageParser.parse(raw)) else {
            Issue.record("Expected response")
            return
        }
        #expect(response.cacheControl == 1800)
    }
}

@Suite("SSDPMessageParser — NOTIFY")
struct SSDPMessageParserNotifyTests {

    @Test("Roku NOTIFY alive parses with UPnP 1.1 BOOTID/CONFIGID")
    func parsesRokuAlive() throws {
        let raw = try fixture("notify-alive-roku")
        let message = try #require(SSDPMessageParser.parse(raw))
        guard case .notify(let n) = message else {
            Issue.record("Expected .notify, got \(message)")
            return
        }
        guard case .alive(let ad) = n else {
            Issue.record("Expected .alive, got \(n)")
            return
        }
        #expect(ad.location == URL(string: "http://192.168.1.77:8060/dial/dd.xml"))
        #expect(ad.usn ==
            "uuid:roku:ecp:YR0070123456::urn:dial-multiscreen-org:device:dial:1")
        #expect(ad.cacheControl == 1800)
        #expect(ad.bootID == 7)
        #expect(ad.configID == 1)
        #expect(ad.nextBootID == nil)
    }

    @Test("byebye parses without LOCATION (LOCATION optional for byebye)")
    func parsesByebye() throws {
        let raw = try fixture("notify-byebye")
        let message = try #require(SSDPMessageParser.parse(raw))
        guard case .notify(let n) = message else {
            Issue.record("Expected .notify, got \(message)")
            return
        }
        guard case .byebye(let ad) = n else {
            Issue.record("Expected .byebye, got \(n)")
            return
        }
        #expect(ad.location == nil)
        #expect(ad.notificationTarget == .mediaServer)
    }

    @Test("ssdp:update parses with NEXTBOOTID")
    func parsesUpdate() throws {
        let raw = try fixture("notify-update")
        let message = try #require(SSDPMessageParser.parse(raw))
        guard case .notify(.update(let ad)) = message else {
            Issue.record("Expected .update, got \(message)")
            return
        }
        #expect(ad.bootID == 23)
        #expect(ad.nextBootID == 24)
    }

    @Test("alive missing LOCATION is rejected")
    func aliveMissingLocationRejected() {
        let raw = """
            NOTIFY * HTTP/1.1\r
            HOST: 239.255.255.250:1900\r
            NT: upnp:rootdevice\r
            NTS: ssdp:alive\r
            USN: uuid:test\r
            \r

            """
        #expect(SSDPMessageParser.parse(raw) == nil)
    }

    @Test("Unknown NTS value is rejected")
    func unknownNTSRejected() {
        let raw = """
            NOTIFY * HTTP/1.1\r
            HOST: 239.255.255.250:1900\r
            NT: upnp:rootdevice\r
            NTS: ssdp:nonsense\r
            USN: uuid:test\r
            \r

            """
        #expect(SSDPMessageParser.parse(raw) == nil)
    }
}

@Suite("SSDPMessageParser — request line")
struct SSDPMessageParserRequestLineTests {
    @Test("M-SEARCH request returns .searchRequest case")
    func recognizesMSearch() {
        let raw = """
            M-SEARCH * HTTP/1.1\r
            HOST: 239.255.255.250:1900\r
            MAN: "ssdp:discover"\r
            MX: 3\r
            ST: ssdp:all\r
            \r

            """
        let message = SSDPMessageParser.parse(raw)
        if case .searchRequest = message {} else {
            Issue.record("Expected .searchRequest, got \(String(describing: message))")
        }
    }
}

// MARK: - Test helpers

func fixture(_ name: String) throws -> String {
    let url = try #require(Bundle.module.url(forResource: name, withExtension: "txt",
                                              subdirectory: "Fixtures"))
    return try String(contentsOf: url, encoding: .utf8)
}
