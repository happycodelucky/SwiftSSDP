//
//  SSDPSearchTargetTests.swift
//  SwiftSSDP
//
//  Copyright © 2017-2026 Paul Bates. All rights reserved.
//

import Testing
@testable import SwiftSSDP

@Suite("SSDPSearchTarget")
struct SSDPSearchTargetTests {

    @Test("rawValue serializes each case to canonical wire form")
    func rawValueSerialization() {
        #expect(SSDPSearchTarget.all.rawValue == "ssdp:all")
        #expect(SSDPSearchTarget.rootDevice.rawValue == "upnp:rootdevice")
        #expect(SSDPSearchTarget.uuid("550e8400-e29b-41d4-a716").rawValue
            == "uuid:550e8400-e29b-41d4-a716")
        #expect(SSDPSearchTarget.deviceType(schema: "schemas-upnp-org",
                                            deviceType: "MediaServer",
                                            version: 1).rawValue
            == "urn:schemas-upnp-org:device:MediaServer:1")
        #expect(SSDPSearchTarget.serviceType(schema: "schemas-upnp-org",
                                             serviceType: "AVTransport",
                                             version: 2).rawValue
            == "urn:schemas-upnp-org:service:AVTransport:2")
    }

    @Test("init?(rawValue:) round-trips canonical forms",
          arguments: [
            SSDPSearchTarget.all,
            .rootDevice,
            .uuid("550e8400-e29b-41d4-a716"),
            .deviceType(schema: "schemas-upnp-org", deviceType: "ZonePlayer", version: 1),
            .serviceType(schema: "schemas-upnp-org", serviceType: "ContentDirectory", version: 1),
          ])
    func roundTrip(target: SSDPSearchTarget) {
        let raw = target.rawValue
        let parsed = SSDPSearchTarget(rawValue: raw)
        #expect(parsed == target)
    }

    @Test("init?(rawValue:) rejects malformed inputs")
    func rejectsMalformed() {
        #expect(SSDPSearchTarget(rawValue: "") == nil)
        #expect(SSDPSearchTarget(rawValue: "garbage") == nil)
        #expect(SSDPSearchTarget(rawValue: "ssdp:nope") == nil)
        // version not an integer
        #expect(SSDPSearchTarget(rawValue: "urn:schemas-upnp-org:device:Foo:notanumber") == nil)
        // wrong middle token
        #expect(SSDPSearchTarget(rawValue: "urn:schemas-upnp-org:gizmo:Foo:1") == nil)
    }

    @Test("UPnP convenience constants resolve to expected wire forms")
    func upnpConvenience() {
        #expect(SSDPSearchTarget.mediaServer.rawValue
            == "urn:schemas-upnp-org:device:MediaServer:1")
        #expect(SSDPSearchTarget.avTransportService.rawValue
            == "urn:schemas-upnp-org:service:AVTransport:1")
    }

    @Test("Hashable groups equivalent values")
    func hashableEquivalence() {
        let a: SSDPSearchTarget = .deviceType(schema: "x", deviceType: "y", version: 1)
        let b: SSDPSearchTarget = .deviceType(schema: "x", deviceType: "y", version: 1)
        var set: Set<SSDPSearchTarget> = []
        set.insert(a)
        set.insert(b)
        #expect(set.count == 1)
    }
}
