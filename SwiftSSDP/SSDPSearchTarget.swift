//
//  SSDPSearchTarget.swift
//  SwiftSSDP
//
//  Created by Paul Bates on 2/7/17.
//  Copyright © 2017 Paul Bates. All rights reserved.
//

import Foundation

/// A device search target for the request. Search targets are represented as ST in M-SEARCH requests and NT in responses.
public enum SSDPSearchTarget {
    /// Search for all devices and services
    case all
    /// Search for root devices only
    case rootDevice
    /// Search for a particular device. Device UUID specified by UPnP vendor
    case uuid(uuid: String)
    /// Search for any device of this type. Domain name, device type and version defined by UPnP vendor. Period
    /// characters in the domain name must be replaced with hyphens in accordance with RFC 2141.
    case deviceType(schema: String, deviceType: String, version: Int)
    /// Search for any service of this type. Domain name, service type and version defined by UPnP vendor.
    /// Period characters in the domain name must be replaced with hyphens in accordance with RFC 2141.
    case serviceType(schema: String, serviceType: String, version: Int)
    
    /// Initialize a SearchTarget from a search target/notify target
    ///
    /// - Parameters:
    ///     - rawValue: Raw search target from a response
    init?(rawValue: String) {
        let components = rawValue.components(separatedBy: ":")
        if components.isEmpty {
            return nil
        }
        
        if components.count == 2 {
            if components[0] == "ssdp" {
                if components[1] == "all" {
                    self = .all
                    return
                }
            } else if components[0] == "upnp" {
                if components[1] == "rootdevice" {
                    self = .rootDevice
                    return
                }
            } else if components[0] == "uuid" {
                self = .uuid(uuid: components[1])
                return
            }
        } else if components.count == 5, let version = Int(components[4], radix: 10) {
            if components[0] == "urn" {
                if components[2] == "device" {
                    self = .deviceType(schema: components[1], deviceType: components[3], version: version)
                    return
                } else if components[2] == "service" {
                    self = .serviceType(schema: components[1], serviceType: components[3], version: version)
                    return
                }
            }
        }
        
        return nil
    }
    
    /// Search target term used in the M-SEARCH as ST or in NOTIFY responses a NT
    public var searchTarget: String {
        switch self {
        case .all:
            return "ssdp:all"
        case .rootDevice:
            return "upnp:rootdevice"
        case .uuid(let uuid):
            return "uuid:\(uuid)"
        case .deviceType(let schema, let deviceType, let version):
            return "urn:\(schema):device:\(deviceType):\(version)"
        case .serviceType(let schema, let serviceType, let version):
            return "urn:\(schema):service:\(serviceType):\(version)"
        }
    }
    
    /// Schema to use with `DeviceType` or `ServiceType` to UPnP forum working committee devices or services
    public static let upnpOrgSchema: String = "schemas-upnp-org"
}

//
// MARK: -
//

// SSDPSearchTarget: CustomStringConvertible
extension SSDPSearchTarget: Equatable, CustomStringConvertible {
    public static func ==(lhs: SSDPSearchTarget, rhs: SSDPSearchTarget) -> Bool {
        switch (lhs, rhs) {
        case (.all, .all):
            return true
        case (.rootDevice, .rootDevice):
            return true
        case (.uuid(let lid), .uuid(let rid)):
            return lid == rid
        case (.deviceType(let lSchema, let lType, let lVer), .deviceType(let rSchema, let rType, let rVer)):
            return lSchema == rSchema && lType == rType && lVer == rVer
        case (.serviceType(let lSchema, let lType, let lVer), .serviceType(let rSchema, let rType, let rVer)):
            return lSchema == rSchema && lType == rType && lVer == rVer
        default:
            return false
        }
    }
    
    public var description: String {
        return self.searchTarget
    }
}
