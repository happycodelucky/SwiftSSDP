//
//  SSDPUPnP.swift
//  SwiftSSDP
//
//  Created by Paul Bates on 2/14/17.
//  Copyright © 2017 Paul Bates. All rights reserved.
//

import Foundation

// Extended SSDPSearchTarget service and device search targets offically declared by UPnP.org
extension SSDPSearchTarget {
    
    //
    // MARK: - UPnP Audio/Video
    //
    
    static let deviceMediaServer: SSDPSearchTarget = .deviceType(schema: SSDPSearchTarget.upnpOrgSchema, deviceType: "MediaServer", version: 1)
    static let deviceMediaRenderer: SSDPSearchTarget = .deviceType(schema: SSDPSearchTarget.upnpOrgSchema, deviceType: "MediaRenderer", version: 1)
    
    static let serviceAVTransport: SSDPSearchTarget = .serviceType(schema: SSDPSearchTarget.upnpOrgSchema, serviceType: "AVTransport", version: 1)
    static let serviceConnectionManager: SSDPSearchTarget = .serviceType(schema: SSDPSearchTarget.upnpOrgSchema, serviceType: "ConnectionManager", version: 1)
    static let serviceContentDirectory: SSDPSearchTarget = .serviceType(schema: SSDPSearchTarget.upnpOrgSchema, serviceType: "ContentDirectory", version: 1)
    static let serviceRenderingControl: SSDPSearchTarget = .serviceType(schema: SSDPSearchTarget.upnpOrgSchema, serviceType: "RenderingControl", version: 1)
    
    //
    // MARK: - UPnP Internet Gateway Device (IGD)
    //
    
    static let deviceInternetGatewayDevice: SSDPSearchTarget = .deviceType(schema: SSDPSearchTarget.upnpOrgSchema, deviceType: "InternetGatewayDevice", version: 1)
    static let deviceWANConnectionDevice: SSDPSearchTarget = .deviceType(schema: SSDPSearchTarget.upnpOrgSchema, deviceType: "WANConnectionDevice", version: 1)
    static let deviceWANDevice: SSDPSearchTarget = .deviceType(schema: SSDPSearchTarget.upnpOrgSchema, deviceType: "WANDevice", version: 1)
    
    static let serviceLayer3Forwarding: SSDPSearchTarget = .serviceType(schema: SSDPSearchTarget.upnpOrgSchema, serviceType: "Layer3Forwarding", version: 1)
    static let serviceWANCommonInterfaceConfig: SSDPSearchTarget = .serviceType(schema: SSDPSearchTarget.upnpOrgSchema, serviceType: "WANCommonInterfaceConfig", version: 1)
    static let serviceWANIPConnection: SSDPSearchTarget = .serviceType(schema: SSDPSearchTarget.upnpOrgSchema, serviceType: "WANIPConnection", version: 1)
}
