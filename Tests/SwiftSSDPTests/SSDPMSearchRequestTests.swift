//
//  SSDPMSearchRequestTests.swift
//  SwiftSSDP
//
//  Copyright © 2017-2026 Paul Bates. All rights reserved.
//

import Testing
@testable import SwiftSSDP

@Suite("SSDPMSearchRequest")
struct SSDPMSearchRequestTests {

    @Test("Default request serializes to deterministic wire format")
    func defaultSerialization() {
        let request = SSDPMSearchRequest(searchTarget: .rootDevice)
        let expected = """
            M-SEARCH * HTTP/1.1\r
            HOST: 239.255.255.250:1900\r
            MAN: "ssdp:discover"\r
            MX: 1\r
            ST: upnp:rootdevice\r
            \r

            """
        #expect(request.message == expected)
    }

    @Test("MX value is honored")
    func customMaxWait() {
        let request = SSDPMSearchRequest(searchTarget: .all, maxWait: 5)
        #expect(request.message.contains("MX: 5\r\n"))
    }

    @Test("Custom non-standard headers are merged but cannot override standard ones")
    func customHeaders() {
        let request = SSDPMSearchRequest(
            searchTarget: .rootDevice,
            otherHeaders: [
                "X-Custom-Token": "abc123",
                "MX": "999",        // Should be ignored — standard header takes precedence
            ]
        )
        let msg = request.message
        #expect(msg.contains("X-CUSTOM-TOKEN: abc123\r\n"))
        #expect(msg.contains("MX: 1\r\n"))
        #expect(!msg.contains("MX: 999"))
    }

    @Test("Header order is alphabetical for testability")
    func deterministicOrder() {
        let request = SSDPMSearchRequest(searchTarget: .all)
        let lines = request.message.components(separatedBy: "\r\n")
        // First line is M-SEARCH, then HOST, MAN, MX, ST in alphabetical order.
        #expect(lines[0] == "M-SEARCH * HTTP/1.1")
        #expect(lines[1].hasPrefix("HOST: "))
        #expect(lines[2].hasPrefix("MAN: "))
        #expect(lines[3].hasPrefix("MX: "))
        #expect(lines[4].hasPrefix("ST: "))
    }
}
