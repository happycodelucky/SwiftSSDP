//
//  SSDPSearchTarget.swift
//  SwiftSSDP
//
//  Copyright © 2017-2026 Paul Bates. All rights reserved.
//

import Foundation

/// A device or service search target.
///
/// Search targets serve double duty in SSDP: they appear as `ST` in M-SEARCH requests and
/// search responses, and as `NT` in NOTIFY broadcasts. The wire format is identical in
/// both roles, so a single value type covers both.
///
/// All cases follow the canonical UPnP forms:
///
/// - `all` → `ssdp:all`
/// - `rootDevice` → `upnp:rootdevice`
/// - `uuid` → `uuid:<UUID>`
/// - `deviceType` → `urn:<schema>:device:<type>:<version>`
/// - `serviceType` → `urn:<schema>:service:<type>:<version>`
public enum SSDPSearchTarget: Sendable, Hashable {
    /// `ssdp:all` — match any device or service.
    case all
    /// `upnp:rootdevice` — match root devices only.
    case rootDevice
    /// `uuid:<UUID>` — match a specific device by its UUID.
    case uuid(String)
    /// `urn:<schema>:device:<type>:<version>` — match any device of the given type.
    ///
    /// Per RFC 2141, period characters in the schema must be replaced with hyphens.
    case deviceType(schema: String, deviceType: String, version: Int)
    /// `urn:<schema>:service:<type>:<version>` — match any service of the given type.
    ///
    /// Per RFC 2141, period characters in the schema must be replaced with hyphens.
    case serviceType(schema: String, serviceType: String, version: Int)

    /// Schema string for UPnP forum working-committee devices and services.
    public static let upnpOrgSchema = "schemas-upnp-org"

    /// The wire string form, suitable for use as `ST` or `NT` header values.
    public var rawValue: String {
        switch self {
        case .all:
            return "ssdp:all"
        case .rootDevice:
            return "upnp:rootdevice"
        case .uuid(let id):
            return "uuid:\(id)"
        case .deviceType(let schema, let type, let version):
            return "urn:\(schema):device:\(type):\(version)"
        case .serviceType(let schema, let type, let version):
            return "urn:\(schema):service:\(type):\(version)"
        }
    }

    /// Parse a search target from a wire string (`ST` / `NT` header value).
    ///
    /// Returns `nil` if the string does not match one of the recognized SSDP forms.
    /// Lenient parsing is intentional — some devices send slightly malformed URNs and
    /// we'd rather surface them as `nil` than crash, but valid forms are accepted.
    public init?(rawValue: String) {
        let components = rawValue.components(separatedBy: ":")
        guard !components.isEmpty else { return nil }

        switch components.count {
        case 2:
            switch components[0] {
            case "ssdp" where components[1] == "all":
                self = .all
            case "upnp" where components[1] == "rootdevice":
                self = .rootDevice
            case "uuid":
                self = .uuid(components[1])
            default:
                return nil
            }
        case 5:
            // urn:<schema>:device|service:<type>:<version>
            guard components[0] == "urn",
                  let version = Int(components[4])
            else { return nil }
            switch components[2] {
            case "device":
                self = .deviceType(schema: components[1], deviceType: components[3], version: version)
            case "service":
                self = .serviceType(schema: components[1], serviceType: components[3], version: version)
            default:
                return nil
            }
        default:
            return nil
        }
    }
}

extension SSDPSearchTarget: CustomStringConvertible {
    public var description: String { rawValue }
}
