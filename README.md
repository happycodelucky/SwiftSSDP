# SwiftSSDP [![GitHub license](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/pryomoax/SwiftAbstractLogger/blob/master/LICENSE) [![GitHub release](https://img.shields.io/badge/version-v0.3.0-brightgreen.svg)](https://github.com/pryomoax/SwiftAbstractLogger/releases) ![Github stable](https://img.shields.io/badge/stable-true-brightgreen.svg)
Simple Service Discovery Protocol ([SSDP](https://en.wikipedia.org/wiki/Simple_Service_Discovery_Protocol)) session based discovery package for Swift.

# Package Management

## Installation
[![GitHub spm](https://img.shields.io/badge/spm-supported-green.svg)](https://swift.org/package-manager/)
[![GitHub carthage](https://img.shields.io/badge/carthage-supported-green.svg)](https://github.com/Carthage/Carthage)
[![GitHub cocoapod](https://img.shields.io/badge/cocoapods-soon-red.svg)](http://cocoapods.org/)

### Using Swift Package Manager
SwiftSSDP is available through [Swift Package Manager](https://swift.org/package-manager/). To install it, simply add the following line to your `Package.swift` dependencies:

```
.Package(url: "https://github.com/pryomoax/SwiftSSDP.git", majorVersion: 0, minor: 3)
```

### Using Carthage
SwiftSSDP is available through [Carthage](https://github.com/Carthage/Carthage). To install it, simply add the following line to your `Cartfile`:

```
# SwiftSSDP
github "pryomoax/SwiftSSDP.git" ~> 0.3
```

### Using CocoaPods

SwiftSSDP is currently not supported by CocoaPods (coming soon)

# Usage

[SSDP](https://en.wikipedia.org/wiki/Simple_Service_Discovery_Protocol) can be used for many things, discovering devices or services. Sonos uses SSDP for device discovery and using the `urn:schemas-upnp-org:device:ZonePlayer:1` search target (ST) devices can be discovered and inspected.

Below is a simple class to start and stop Sonos device discovery. It uses a `10` second timeout, which will automatically close the discovery session `session` if not closed explictly.

[SSDP](https://en.wikipedia.org/wiki/Simple_Service_Discovery_Protocol) utilized [UDP](https://en.wikipedia.org/wiki/User_Datagram_Protocol) which is unreliable and even less reliable over WiFi. SwiftSSDP automatically repeats [MSEARCH](http://www.upnp.org/specs/arch/UPnP-arch-DeviceArchitecture-v1.0-20080424.pdf) broadcasts to ensure discovery of all devices. SwiftSSDP gradually backs off the interval MSEARCH broadcasts are sent from 1/second to 1/minute. Discovery should be short lived as not to flood the network with broadcasts. Without a timeout the session should be closed explictly.

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
   }

}
```

