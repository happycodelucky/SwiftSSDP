//
//  SSDPDiscoverySession.swift
//  SwiftSSDP
//
//  Created by Paul Bates on 2/4/17.
//  Copyright © 2017 Paul Bates. All rights reserved.
//

import Foundation
import SwiftAbstractLogger

/// SSDPDiscovery based session returned from `SSDPDiscovery`'s `startDiscovery`.
///
/// A `SSDPDiscoverySession` should be retained by a client to ensure the session remains active and to `close()` the session when done.
/// Alternatively is a session was started and has a timeout it may be used in a fire-&-forget manner because the session will 
/// automatically close when the timeout expires.
///
/// Sessions will keep sending M-SEARCH requests to aid discover at a stepped cadence based on how long the session has been running.
/// This is a recommendation of UPnP due to the unreliable nature of UDP, especially over WiFi. To prevent flooding the network with 
/// M-SEARCH broadcast packets the cadence will back off incrementally in steps, starting at 1 search/second to 1 search/minute. It's 
/// to this reason why sessions should be closed as soon as the devices/services are discovered.
///
/// To close a session, once devices have been discovered or a designated amount of time has elapsed, call `close()`. It is not recommended
/// to rely on `SSDPDiscoverySession` being reclaimed to end the session.
///
/// - Note: 
///     Failure to close a session will log warnings
public class SSDPDiscoverySession: Equatable {
    public let request: SSDPMSearchRequest
    
    /// All discovered devices for the session
    public var responses: Set<SSDPMSearchResponse> {
        return internalResponses
    }
    
    /// Phase of the session. Once `Closed` a session can never be restarted.
    public var phase: Phase {
        return internalPhase;
    }
    
    /// Session phase
    ///
    /// - Unknown: Session has not been fully initialized and started yet
    /// - Searching: Session is actively search for devices
    /// - Closed: Sessions has closed and will no longer be able to perform device discovery
    public enum Phase {
        case unknown
        case searching
        case closed
    }
    
    //
    // MARK: Initialization
    //
    
    /// Initialize the session for an M-SEARCH `request` and a `discovery`
    ///
    /// - Parameters:
    ///     - request: M-SEARCH request with the relevant M-SEARCH search target and delegate to callback
    ///     - timeout: optional Timeout interval to automatically close the session after
    ///     - discovery: Discovery object to make M-SEARCH broadcast through and recieve raw responses from
    internal init(request: SSDPMSearchRequest, discovery: SSDPDiscovery, timeout: TimeInterval?) {
        self.request = request
        self.timeout = timeout
        self.discovery = discovery
        self.internalResponses = Set()
    }
    
    deinit {
        close()
    }
    
    //
    // MARK: Public Functions
    //
    
    /// Closes the session and halts any further M-SEARCH requests.
    ///
    /// Once closed a session cannot be reopened, and any responses from in-flight M-SEARCH broadcasts will be ignored
    public func close() {
        if let timer = self.broadcastTimer {
            timer.invalidate()
            self.broadcastTimer = nil
        }
        if let closeTimer = self.timeoutTimer {
            closeTimer.invalidate()
            self.timeoutTimer = nil
        }
        
        self.discovery?.closeSession(session: self)
        self.discovery = nil
        self.internalPhase = .closed
    }
    
    //
    // MARK: Internal Functions
    //
    
    /// Starts the session, and performs the first M-SEARCH request
    ///
    /// Only to be called internally
    internal func start() {
        if self.phase != .unknown {
            return
        }
        
        self.startDate = Date()
        self.checkDate = self.startDate
        self.internalPhase = .searching
        
        // Schedule timer for auto-session expiration
        if let timeout = self.timeout {
            // Intended to reference `self` because we can use fire-and-forget when using a timer
            // close() will cancel the timer in other cases and deinit.
            self.timeoutTimer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false, block: { (timer) in
                self.forceClose()
            })
        }
        
        sendSearchRequest()
    }
    
    /// Forces the session to close.
    ///
    /// Only to be called internally
    internal func forceClose() {
        close()
        
        self.closedSession(self)
    }
    
    //
    // MARK: Private Functions
    //
    
    /// Schedules the next timer based on the current time and start time. Timer cadence changes at intervals to ensure the network
    /// is not flooded with M-SEARCH broadcasts.
    private func scheduleNextTimer() {
        assert(self.phase == .searching)
        let now = Date()
        
        let interval = now.timeIntervalSince(self.startDate)
        let cadence = SSDPDiscoverySession.timerCadence(forTimeInterval: interval)
        self.broadcastTimer = Timer.scheduledTimer(withTimeInterval: cadence, repeats: false, block: { [unowned self] (Timer) in
            if (self.phase == .searching) {
                self.sendSearchRequest()
            }
        })
        
        // Log a check to ensure the session is correctly closed
        if now.timeIntervalSince(self.checkDate) > 30 {
            logWarning(category: loggerDiscoveryCategory, "Session has been running longer than 30 seconds!")
            self.checkDate = now
        }
    }
    
    /// Actually sends a single M-SEARCH on the LAN and schedules the next timer for the next M-SEARCH
    private func sendSearchRequest() {
        assert(self.phase == .searching)
        self.discovery?.sendRequestMessage(request: self.request)
        scheduleNextTimer()
    }
    
    /// Calculates the timer cadence based on the time the session has been performing M-SEARCHs for.
    private static func timerCadence(forTimeInterval interval: TimeInterval) -> TimeInterval {
        if interval >= 60.0 {
            return 60.0
        } else if interval >= 10.0 {
            return 10.0
        } else if interval >= 5.0 {
            return 3.0
        } else {
            return 1.0
        }
    }
    
    //
    // MARK: Private instance variables
    //
    
    private weak var discovery: SSDPDiscovery?
    
    private var internalPhase: Phase = .unknown
    private var startDate: Date!
    private var checkDate: Date!
    private var broadcastTimer: Timer?
    
    private var timeout: TimeInterval?
    private var timeoutTimer: Timer?
    
    // Discovered devices and services
    fileprivate var internalResponses: Set<SSDPMSearchResponse>
}

//
// MARK: - 
//

extension SSDPDiscoverySession: SSDPDiscoveryDelegate {
    public func discoveredDevice(response: SSDPMSearchResponse, session: SSDPDiscoverySession) {
        // TODO: Add a write lock here to synchronize `internalResponses`
        if !internalResponses.contains(response) {
            internalResponses.insert(response)
            
            self.request.delegate.discoveredDevice(response: response, session: session)
        }
    }
    
    public func discoveredService(response: SSDPMSearchResponse, session: SSDPDiscoverySession) {
        // TODO: Add a write lock here to synchronize `internalResponses`
        if !internalResponses.contains(response) {
            internalResponses.insert(response)
            
            self.request.delegate.discoveredService(response: response, session: session)
        }
    }
    
    public func closedSession(_ session: SSDPDiscoverySession) {
        self.request.delegate.closedSession(session)
    }
}

//
// MARK: -
//

public func ==(lhs: SSDPDiscoverySession, rhs: SSDPDiscoverySession) -> Bool {
    return lhs === rhs;
}
