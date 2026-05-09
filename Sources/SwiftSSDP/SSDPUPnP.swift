//
//  SSDPUPnP.swift
//  SwiftSSDP
//
//  Copyright © 2017-2026 Paul Bates. All rights reserved.
//

import Foundation

/// Convenience constants for common UPnP forum-defined device and service types.
///
/// All constants use `SSDPSearchTarget.upnpOrgSchema` (`schemas-upnp-org`) and version `1`.
/// For other vendors or versions, construct the search target directly.
public extension SSDPSearchTarget {
    // MARK: - UPnP Devices

    /// `urn:schemas-upnp-org:device:MediaServer:1`
    static let mediaServer: SSDPSearchTarget =
        .deviceType(schema: upnpOrgSchema, deviceType: "MediaServer", version: 1)

    /// `urn:schemas-upnp-org:device:MediaRenderer:1`
    static let mediaRenderer: SSDPSearchTarget =
        .deviceType(schema: upnpOrgSchema, deviceType: "MediaRenderer", version: 1)

    /// `urn:schemas-upnp-org:device:InternetGatewayDevice:1`
    static let internetGatewayDevice: SSDPSearchTarget =
        .deviceType(schema: upnpOrgSchema, deviceType: "InternetGatewayDevice", version: 1)

    /// `urn:schemas-upnp-org:device:WANConnectionDevice:1`
    static let wanConnectionDevice: SSDPSearchTarget =
        .deviceType(schema: upnpOrgSchema, deviceType: "WANConnectionDevice", version: 1)

    /// `urn:schemas-upnp-org:device:WANDevice:1`
    static let wanDevice: SSDPSearchTarget =
        .deviceType(schema: upnpOrgSchema, deviceType: "WANDevice", version: 1)

    // MARK: - UPnP Services

    /// `urn:schemas-upnp-org:service:AVTransport:1`
    static let avTransportService: SSDPSearchTarget =
        .serviceType(schema: upnpOrgSchema, serviceType: "AVTransport", version: 1)

    /// `urn:schemas-upnp-org:service:ConnectionManager:1`
    static let connectionManagerService: SSDPSearchTarget =
        .serviceType(schema: upnpOrgSchema, serviceType: "ConnectionManager", version: 1)

    /// `urn:schemas-upnp-org:service:ContentDirectory:1`
    static let contentDirectoryService: SSDPSearchTarget =
        .serviceType(schema: upnpOrgSchema, serviceType: "ContentDirectory", version: 1)

    /// `urn:schemas-upnp-org:service:RenderingControl:1`
    static let renderingControlService: SSDPSearchTarget =
        .serviceType(schema: upnpOrgSchema, serviceType: "RenderingControl", version: 1)

    /// `urn:schemas-upnp-org:service:Layer3Forwarding:1`
    static let layer3ForwardingService: SSDPSearchTarget =
        .serviceType(schema: upnpOrgSchema, serviceType: "Layer3Forwarding", version: 1)

    /// `urn:schemas-upnp-org:service:WANCommonInterfaceConfig:1`
    static let wanCommonInterfaceConfigService: SSDPSearchTarget =
        .serviceType(schema: upnpOrgSchema, serviceType: "WANCommonInterfaceConfig", version: 1)

    /// `urn:schemas-upnp-org:service:WANIPConnection:1`
    static let wanIPConnectionService: SSDPSearchTarget =
        .serviceType(schema: upnpOrgSchema, serviceType: "WANIPConnection", version: 1)
}
