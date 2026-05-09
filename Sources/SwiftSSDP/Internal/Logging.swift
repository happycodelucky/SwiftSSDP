//
//  Logging.swift
//  SwiftSSDP
//
//  Copyright © 2017-2026 Paul Bates. All rights reserved.
//

import os

/// Internal logging facade.
///
/// `os.Logger` is platform-native unified logging — viewable in Console.app and `log stream` on
/// macOS, surfaced in Xcode's debug console, and zero-cost when nothing is reading.
/// All logs are emitted under the subsystem `com.pryomoax.SwiftSSDP`; categories distinguish
/// the source area (transport, parser, listener). Privacy markers default to `.private`,
/// so anything you'd want to read in Console at runtime needs an explicit `.public` marker.
enum SSDPLog {
    /// Subsystem identifier for all SwiftSSDP logs.
    static let subsystem = "com.pryomoax.SwiftSSDP"

    /// Logger for the public `SSDPDiscovery` actor and lifecycle events.
    static let discovery = Logger(subsystem: subsystem, category: "discovery")
    /// Logger for the M-SEARCH transport (`NetworkTransport`).
    static let transport = Logger(subsystem: subsystem, category: "transport")
    /// Logger for the multicast NOTIFY listener.
    static let listener = Logger(subsystem: subsystem, category: "listener")
    /// Logger for SSDP message parsing.
    static let parser = Logger(subsystem: subsystem, category: "parser")
}
