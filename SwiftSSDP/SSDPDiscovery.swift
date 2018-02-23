//
//  SSDPDiscovery.swift
//  SwiftSSDP
//
//  Created by Paul Bates on 2/4/17.
//  Copyright © 2017 Paul Bates. All rights reserved.
//

import Foundation
import CocoaAsyncSocket
import SwiftAbstractLogger
import Weak

//
// MARK: - Protocols
//

/// Delegate for device discovery
public protocol SSDPDiscoveryDelegate {
    /// Called when a requested device has been discovered
    func discoveredDevice(response: SSDPMSearchResponse, session: SSDPDiscoverySession)
    
    /// Called when a requested service has been discovered
    func discoveredService(response: SSDPMSearchResponse, session: SSDPDiscoverySession)
    
    /// Called when a session has been closed
    func closedSession(_ session: SSDPDiscoverySession)
}

extension SSDPDiscoveryDelegate {
    func discoveredDevice(response: SSDPMSearchResponse, session: SSDPDiscoverySession) {
        
    }
    
    func discoveredService(response: SSDPMSearchResponse, session: SSDPDiscoverySession) {
        
    }
    
    func closedSession(_ session: SSDPDiscoverySession) {
        
    }
}

//
// MARK: -
//

/// SSDP discovery for UPnP devices on the LAN
///
/// - Note: No checks are in place to ensure connectivity to the local area network
public class SSDPDiscovery: NSObject {
    public static let ssdpHost: String = "239.255.255.250"
    public static let ssdpPort: Int = 1900
    
    /// Singleton access to a discovery operating on the main dispatch queue
    open static let defaultDiscovery = SSDPDiscovery()
    
    /// Private initialization using the global queue
    private override init() {
        
    }
    
    /// Init a new discovery with an alternative queue to handle responses on. By default responses are handled on the main dispatch queue.
    ///
    /// - Parameters:
    ///     - responseQueue: a dispatch queue to process and dispatch responses to
    public init(responseQueue: DispatchQueue) {
        self.responseQueue = responseQueue
    }
    
    //
    // MARK: Public functions
    //
    
    /// Starts a discovery session based on an M-SEARCH `request`.
    ///
    /// Clients are in control of the session lifetime and should retain the returned `SSDPDiscoverySession` else the session close 
    /// immediately, unless an explict `timeout` is used. When a timeout is used the session will auto close after the timeout 
    /// automatically. For more information about discovery sessions see `SSDPDiscoverySessions`.
    ///
    /// - Parameters:
    ///    - request: The M-SEARCH request representing the devices to discover
    ///    - timeout: Time interval to automatically close the returned session after
    ///
    /// - Throws: `NSError` if there was an error establishing the socket for M-SEARCH broadcasts on the LAN
    open func startDiscovery(request: SSDPMSearchRequest, timeout: TimeInterval? = nil) throws -> SSDPDiscoverySession {
        try initDiscoverySocket()
        
        assert(self.asyncUdpSocket != nil)
        assert(!self.asyncUdpSocket!.isClosed())
        assert(self.ssdpResponseQueue != nil)
        
        return startSession(request: request, timeout: timeout)
    }
    
    /// Halts all discovery in flight for all `SSDPDisoverySession`s. Use with care t prevent unintented stopping of active sessions.
    ///
    /// Typically this will be used when a local network adapter becomes unavailable and all active sessions should be stopped.
    open func stopAllDiscovery() {
        // Close all sessions
        activeSessions.forEach { $0.object?.forceClose() }
        
        // Should have deinit all things now
        assert(self.activeSessions.isEmpty)
        assert(self.asyncUdpSocket == nil)
        assert(self.ssdpResponseQueue === nil)
    }
    
    //
    // MARK: Private Functions
    //
    
    func handleMessage(_ message: SSDPMessage) {
        var responseSearchTarget: SSDPSearchTarget?
        switch message {
        case .searchResponse(let response):
            responseSearchTarget = response.searchTarget
            break
            
        default:
            break
        }
        
        if let searchTarget = responseSearchTarget {
            // We should not be getting responses with ssdp:all
            if searchTarget == .all {
                SwiftAbstractLogger.logWarning("Received MSEARCH response with ssdp:all")
                return;
            }
            
            for weakSession in activeSessions {
                guard let session = weakSession.object else {
                    continue
                }
                
                // Check if the session is capable of handling the target
                let request = session.request
                if request.searchTarget == searchTarget || request.searchTarget == SSDPSearchTarget.all {
                    switch message {
                    case .searchResponse(let response):
                        switch searchTarget {
                        case .all:
                            break
                            
                        case .rootDevice, .uuid, .deviceType:
                            session.discoveredDevice(response: response, session: session)
                            break
                            
                        case .serviceType:
                            session.discoveredService(response: response, session: session)
                            break
                        }
                        
                    default:
                        break
                    }
                    
                }
            }
        }
    }
    
    /// Initializes the socket used to perform device discovery on the local area network
    private func initDiscoverySocket() throws {
        // Check if the socket has already been created
        if self.asyncUdpSocket != nil {
            return
        }
        
        // We'll use a different queue for handling responses so we can parse and process
        // responses off the main queue.
        var ssdpQueue = self.ssdpResponseQueue
        if ssdpQueue == nil {
            ssdpQueue = self.responseQueue
            // If we are not on the main queue then we'll reuse the response queue for SSDP response processing
            if ssdpQueue == nil || ssdpQueue == DispatchQueue.main {
                ssdpQueue = DispatchQueue(label: loggerDiscoveryCategory, qos: .background, attributes: .concurrent, autoreleaseFrequency: .inherit, target: DispatchQueue.main)
            }
        }
        ssdpQueue = DispatchQueue.main
        let socket = GCDAsyncUdpSocket(delegate: self, delegateQueue: DispatchQueue.main)
        try socket.enableBroadcast(true)
        try socket.beginReceiving()
        
        self.asyncUdpSocket = socket
        self.ssdpResponseQueue = ssdpQueue!
    }
    
    /// Cleans up the discover socket when no more sessions are active
    fileprivate func deinitDiscoverySocket() {
        assert(activeSessions.isEmpty)
        
        self.asyncUdpSocket?.close()
        self.asyncUdpSocket = nil
        self.ssdpResponseQueue = nil
    }
    
    //
    // MARK: Private Instance Variables
    //
    
    fileprivate var activeSessions: [Weak<SSDPDiscoverySession>] = []
    fileprivate var asyncUdpSocket: GCDAsyncUdpSocket?
    private var ssdpResponseQueue: DispatchQueue?
    private var responseQueue: DispatchQueue?
}

//
// MARK: - Session management
//

extension SSDPDiscovery {
    
    /// Starts a new session based on an M-SEARCH `request`.
    ///
    /// - Parameters:
    ///     - request: The M-SEARCH request representing the devices to discover
    ///     - timeout: Time interval to automatically close the session after
    ///
    /// - Returns: A new discovery session for the request
    internal func startSession(request: SSDPMSearchRequest, timeout: TimeInterval? = nil) -> SSDPDiscoverySession {
        let session = SSDPDiscoverySession(request: request, discovery: self, timeout: timeout)
        self.activeSessions.append(Weak(session))
        session.start()
        return session
    }
    
    /// Sends a single M-SEARCH broadcast over the local area network to discover devices. Sending a request does not guarentee a response
    /// given the unreliablity of UDP.
    ///
    /// - Parameters:
    ///     - request: The M-SEARCH request representing the devices to discover
    internal func sendRequestMessage(request: SSDPMSearchRequest) {
        if let socket = self.asyncUdpSocket {
            let messageData = request.message.data(using: .utf8)!
            socket.send(messageData, toHost: SSDPDiscovery.ssdpHost, port: UInt16(SSDPDiscovery.ssdpPort), withTimeout: -1, tag: 1000)
        }
    }
    
    /// Closes a session and removs the association from the discovery. Once all sessions are close the discovery is free to reclaim
    /// the sockets.
    ///
    /// - Parameters:
    ///     - session: The session to close
    internal func closeSession(session: SSDPDiscoverySession) {
        let count = self.activeSessions.count
        self.activeSessions = activeSessions.filter { $0.object != nil && $0.object !== session as SSDPDiscoverySession? }
        if activeSessions.isEmpty && count != self.activeSessions.count {
            deinitDiscoverySocket()
        }
    }
}

//
// MARK: - GCDAsyncUdpSocketDelegate
//

extension SSDPDiscovery: GCDAsyncUdpSocketDelegate {
    public func udpSocket(_ sock: GCDAsyncUdpSocket, didConnectToAddress address: Data) {
    }
    
    public func udpSocket(_ sock: GCDAsyncUdpSocket, didNotConnect error: Error?) {
        if (error != nil) {
            SwiftAbstractLogger.logError(category: loggerDiscoveryCategory, "Unable to connect \(String(describing: error))")
        } else {
            SwiftAbstractLogger.logError(category: loggerDiscoveryCategory, "Unable to connect")
        }
    }
    
    public func udpSocket(_ sock: GCDAsyncUdpSocket, didSendDataWithTag tag: Int) {
    }
    
    public func udpSocket(_ sock: GCDAsyncUdpSocket, didNotSendDataWithTag tag: Int, dueToError error: Error?) {
        if (error != nil) {
            SwiftAbstractLogger.logError(category: loggerDiscoveryCategory, "Unable to send data \(String(describing: error))")
        } else {
            SwiftAbstractLogger.logError(category: loggerDiscoveryCategory, "Unable to send data")
        }
    }
    
    public func udpSocket(_ sock: GCDAsyncUdpSocket, didReceive data: Data, fromAddress address: Data, withFilterContext filterContext: Any?) {
        SwiftAbstractLogger.logVerbose(category: loggerDiscoveryCategory, "M-SEARCH response handled")
        SwiftAbstractLogger.logDebug(category: loggerDiscoveryCategory, String(data: data, encoding: .utf8)!)
        
        // Ensure we have parsable data
        guard let messageString = String(data: data, encoding: .utf8) else {
            SwiftAbstractLogger.logError(category: loggerDiscoveryCategory, "Unable to parse M-SEARCH response")
            return
        }
        
        // Construct a real message based on parsing the string message
        guard let message = SSDPMessageParser.parse(response: messageString) else {
            SwiftAbstractLogger.logError(category: loggerDiscoveryCategory, "incomplete M-SEARCH response\n\(messageString)")
            return
        }
        
        self.handleMessage(message)
    }
}
