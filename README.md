# SwiftSSDP ![](https://img.shields.io/badge/swift-4.0-orange.svg) [![GitHub license](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/pryomoax/SwiftSSDP/blob/master/LICENSE) [![GitHub release](https://img.shields.io/badge/version-v0.5.1-brightgreen.svg)](https://github.com/pryomoax/SwiftSSDP/releases) ![Github stable](https://img.shields.io/badge/stable-true-brightgreen.svg)

Simple Service Discovery Protocol ([SSDP](https://en.wikipedia.org/wiki/Simple_Service_Discovery_Protocol)) session based discovery package for Swift.

# Package Management

## Installation
[![GitHub spm](https://img.shields.io/badge/spm-supported-brightgreen.svg)](https://swift.org/package-manager/)
[![GitHub carthage](https://img.shields.io/badge/carthage-supported-brightgreen.svg)](https://github.com/Carthage/Carthage)
[![GitHub cocoapod](https://img.shields.io/badge/cocoapods-soon-red.svg)](http://cocoapods.org/)

### Using Swift Package Manager
SwiftSSDP is available through [Swift Package Manager](https://swift.org/package-manager/). To install it, add the following line to your `Package.swift` dependencies:

```
.Package(url: "https://github.com/pryomoax/SwiftSSDP.git", majorVersion: 0, minor: 5)
```

### Using Carthage
SwiftSSDP is available through [Carthage](https://github.com/Carthage/Carthage). To install it, add the following line to your `Cartfile`:

```
# SwiftSSDP
github "pryomoax/SwiftSSDP.git" ~> 0.5
```

### Using CocoaPods

SwiftSSDP is currently not supported by CocoaPods (coming soon)

# Usage

[SSDP](https://en.wikipedia.org/wiki/Simple_Service_Discovery_Protocol) can be used for many things, discovering devices or services. Sonos uses SSDP for device discovery and using the `urn:schemas-upnp-org:device:ZonePlayer:1` search target (ST) devices can be discovered and inspected.

Below is a simple class to start and stop Sonos device discovery. It uses a `10` second timeout, which will automatically close the discovery session `session` if not closed explictly.

[SSDP](https://en.wikipedia.org/wiki/Simple_Service_Discovery_Protocol) makes use of [UDP](https://en.wikipedia.org/wiki/User_Datagram_Protocol), which is an unreliable transport, and even less reliable over WiFi. SwiftSSDP automatically repeats [MSEARCH](http://www.upnp.org/specs/arch/UPnP-arch-DeviceArchitecture-v1.0-20080424.pdf) broadcasts to ensure discovery of all devices. SwiftSSDP gradually backs off the interval between MSEARCH broadcasts are sent from 1/second to 1/minute. Discovery should be short lived as not to flood the network with broadcasts. Without a timeout the session should be closed explictly.

## Timed Sessions

```swift
public class DeviceDiscovery {

	private let discovery: SSDPDiscovery = SSDPDiscovery.defaultDiscovery
	fileprivate var session: SSDPDiscoverySession?

	public func searchForDevices() {
		// Create the request for Sonos ZonePlayer devices
		let zonePlayerTarget = SSDPSearchTarget.deviceType(schema: SSDPSearchTarget.upnpOrgSchema, deviceType: "ZonePlayer", version: 1)
		let request = SSDPMSearchRequest(delegate: self, searchTarget: zonePlayerTarget)
    
		// Start a discovery session for the request and timeout after 10 seconds of searching.
		self.session = try! discovery.startDiscovery(request: request, timeout: 10.0)
	}
	
	public func stopSearching() {
		self.session?.close()
		self.session = nil
	}
	
}
```

To handle the discovery implement the `SSDPDiscoveryDelegate` protocol, and use when initializing a `SSDPMSearchReqest`

```swift
extension DeviceDiscovery: SSDPDiscoveryDelegate {
    
	public func discoveredDevice(response: SSDPMSearchResponse, session: SSDPDiscoverySession) {
       print("Found device \(response)\n")
   }
    
   public func discoveredService(response: SSDPMSearchResponse, session: SSDPDiscoverySession) {
   }
    
   public func closedSession(_ session: SSDPDiscoverySession) {
       print("Session closed\n")
   }

}
```

# Logging
SwiftSSDP uses [SwiftAbstractLogger](https://github.com/pryomoax/SwiftAbstractLogger) for all logging. Logging can be independently configured for SwiftSSDP using the log category "SSDP". For convenience this is accessible via the `loggerDiscoveryCategory` constant.

```swift
// Attach a default (basic) console logger implementation to Logger
Logger.attach(BasicConsoleLogger.logger)

// Enable debug logging only for SSDPSwift
Logger.configureLevel(category: loggerDiscoveryCategory, level: .Debug)
```

# Package Information

## Requirements

* Xcode 8
* iOS 10.0+

## Author

Paul Bates, **[paul.a.bates@gmail.com](mailto:paul.a.bates@gmail.com)**

## License

SwiftSSDP is available under the **MIT license**. See the `LICENSE` file for more 
