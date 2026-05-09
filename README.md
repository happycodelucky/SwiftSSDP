# SwiftSSDP

![Swift 6](https://img.shields.io/badge/swift-6-orange.svg?style=for-the-badge&logo=swift)
![Platforms](https://img.shields.io/badge/platforms-iOS%20%7C%20macOS%20%7C%20tvOS-blue.svg?style=for-the-badge&logo=apple)
[![CI](https://img.shields.io/github/actions/workflow/status/happycodelucky/SwiftSSDP/ci.yml?style=for-the-badge&label=ci)](https://github.com/happycodelucky/SwiftSSDP/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/happycodelucky/SwiftSSDP?style=for-the-badge)](https://github.com/happycodelucky/SwiftSSDP/releases/latest)
[![License: MIT](https://img.shields.io/badge/license-MIT-orange.svg?style=for-the-badge)](LICENSE)
[![Maintained](https://img.shields.io/badge/Maintained%3F-yes-green.svg?style=for-the-badge)](https://github.com/happycodelucky/SwiftSSDP/graphs/commit-activity)

A modern Swift package for [Simple Service Discovery Protocol](https://en.wikipedia.org/wiki/Simple_Service_Discovery_Protocol) (SSDP) — the discovery layer of UPnP. SwiftSSDP supports both:

- **Active discovery** — sending M-SEARCH broadcasts and collecting responses.
- **Passive listening** — subscribing to unsolicited NOTIFY broadcasts (`alive`, `byebye`, `update`).

The whole API is async/await — no delegates, no Combine, no callbacks. The only dependency is Apple's `Network.framework`.

> **v2.0.0 is a breaking re-debut.** If you're upgrading from 0.5.x see [MIGRATION.md](MIGRATION.md). (No 1.x was ever released — the version jump goes 0.5.x → 2.0.0 to signal a breaking change without overloading 1.0 semantics that some consumers may have already pinned against.)

## Installation

Add SwiftSSDP via Swift Package Manager:

```swift
.package(url: "https://github.com/happycodelucky/SwiftSSDP.git", from: "2.0.0")
```

Then add `"SwiftSSDP"` to the dependencies of any target that needs it. SwiftSSDP is SPM-only — no Carthage, no CocoaPods.

## Usage

### Active discovery (M-SEARCH)

```swift
import SwiftSSDP

let discovery = SSDPDiscovery()

// Streaming form — see results as they arrive.
for try await response in discovery.search(for: .rootDevice, timeout: 10) {
    print("Found \(response.usn) at \(response.location)")
}
```

For convenience, collect everything into a deduplicated array:

```swift
let devices = try await discovery
    .search(for: .mediaServer, timeout: 10)
    .collect()
print("Found \(devices.count) media servers")
```

Or stop at the first response — handy for "find any device of type X, then move on":

```swift
if let device = try await discovery.firstDevice(for: .mediaServer, timeout: 10) {
    print("First media server: \(device.usn)")
}
// firstDevice() returns nil if the timeout elapses before any response arrives.
```

`firstDevice()` cancels the underlying search the moment the response arrives — sockets, retransmits, and timers all tear down promptly without waiting for the timeout.

### Cancelling a search

Cancellation in Swift Concurrency is cooperative — the library's stream finishes cleanly whenever the consumer signals it's done, and the underlying socket and retransmit task tear down automatically. There are three idiomatic ways:

**1. Break out of the loop** — when you're iterating and decide you've seen enough:

```swift
for try await response in discovery.search(for: .rootDevice) {
    if response.server?.contains("Sonos") == true {
        handle(response)
        break          // ends the search, tears down sockets
    }
}
```

**2. Cancel the parent `Task`** — when the search is running in a Task and an external trigger (button tap, view disappearing, timeout) needs to stop it:

```swift
final class DeviceFinder {
    private var searchTask: Task<Void, Error>?

    func startSearching() {
        searchTask = Task {
            for try await response in discovery.search(for: .rootDevice) {
                await handle(response)
            }
        }
    }

    func stopSearching() {
        searchTask?.cancel()   // Task.isCancelled becomes true; loop exits cleanly
        searchTask = nil
    }
}
```

**3. Use a `timeout` parameter** — simplest of all when you know how long to wait:

```swift
// Stream finishes cleanly after 10 seconds, regardless of whether anything was found.
let devices = try await discovery
    .search(for: .rootDevice, timeout: 10)
    .collect()
```

All three paths run the same teardown: the retransmit task is cancelled, the socket subscriber is removed, and (if no other consumers remain) the underlying multicast socket closes.

### Custom requests

For finer control (custom headers, longer `MX`), pass an explicit `SSDPMSearchRequest`:

```swift
let request = SSDPMSearchRequest(
    searchTarget: .deviceType(schema: .upnpOrgSchema, deviceType: "ZonePlayer", version: 1),
    maxWait: 3,
    otherHeaders: ["X-MyApp-Token": "abc123"]
)
for try await response in discovery.search(request, timeout: 10) {
    print(response)
}
```

The library follows UPnP recommendations and retransmits the M-SEARCH at a stepped cadence (1s up to 5s elapsed → 3s up to 10s → 10s up to 60s → 60s thereafter). UDP is unreliable, especially over Wi-Fi, so this materially improves discovery completeness.

### Passive listening (NOTIFY)

> **iOS / iPadOS / tvOS apps must request the multicast entitlement.** See [iOS multicast entitlement](#ios-multicast-entitlement) below before deploying.

```swift
let discovery = SSDPDiscovery()

for try await notification in discovery.notifications() {
    switch notification {
    case .alive(let advertisement):
        print("→ \(advertisement.usn) joined at \(advertisement.location?.absoluteString ?? "?")")
    case .byebye(let advertisement):
        print("← \(advertisement.usn) left")
    case .update(let advertisement):
        print("⟳ \(advertisement.usn) updated boot ID")
    }
}
```

Notification streams are long-lived — they continue until the consumer breaks the `for try await` loop. Multiple concurrent calls share one underlying multicast group join; the join is reference-counted and tears down when the last subscriber cancels.

Filtering is just a `where` clause:

```swift
for try await n in discovery.notifications() where n.notificationTarget == .rootDevice {
    print("Root device: \(n.advertisement.usn)")
}
```

### Search targets

Common UPnP forum-defined targets are available as static members:

```swift
SSDPSearchTarget.all                       // ssdp:all
SSDPSearchTarget.rootDevice                // upnp:rootdevice
SSDPSearchTarget.mediaServer               // urn:schemas-upnp-org:device:MediaServer:1
SSDPSearchTarget.mediaRenderer
SSDPSearchTarget.internetGatewayDevice
SSDPSearchTarget.avTransportService        // urn:schemas-upnp-org:service:AVTransport:1
SSDPSearchTarget.contentDirectoryService
// …and more — see SSDPUPnP.swift
```

For other vendors or versions, build the target directly:

```swift
let zonePlayer: SSDPSearchTarget = .deviceType(
    schema: .upnpOrgSchema,
    deviceType: "ZonePlayer",
    version: 1
)
```

## iOS multicast entitlement

On iOS, iPadOS, and tvOS (14+), joining the SSDP multicast group `239.255.255.250` requires the **`com.apple.developer.networking.multicast`** entitlement. Apple gates this entitlement behind a manual application form:

> <https://developer.apple.com/contact/request/networking-multicast>

Without the entitlement, `discovery.notifications()` will throw `SSDPError.multicastEntitlementMissing` on the first iteration. `discovery.search(...)` does not require the entitlement (M-SEARCH unicast replies don't need group membership).

**macOS does not require this entitlement.** Run the demo CLI on a Mac to verify behavior before deploying to iOS.

## Demo

A small CLI tool lives under `Examples/ssdp-demo`:

```sh
# Search the LAN for ten seconds and print everything.
swift run --package-path Examples/ssdp-demo ssdp-demo search ssdp:all --timeout 10

# Listen for NOTIFY broadcasts indefinitely (Ctrl-C to stop).
swift run --package-path Examples/ssdp-demo ssdp-demo listen
```

## Logging

SwiftSSDP logs through `os.Logger` under the subsystem `com.pryomoax.SwiftSSDP`. View live logs in Console.app (filter by subsystem) or via `log stream`:

```sh
log stream --predicate 'subsystem == "com.pryomoax.SwiftSSDP"' --level debug
```

Categories: `discovery`, `transport`, `listener`, `parser`.

## Requirements

- **Swift:** 6.0+ (Swift 6 language mode with strict concurrency checking)
- **Xcode:** 16+
- **Platforms:** iOS 17, macOS 14, tvOS 17 (watchOS not supported — multicast is unavailable on watchOS)

The library compiles cleanly under `-strict-concurrency=complete -warnings-as-errors`. Public API surface is fully `Sendable` so it composes naturally with actor-isolated callers.

## License

MIT — see [LICENSE](LICENSE).

## Author

Paul Bates · [paul.a.bates@gmail.com](mailto:paul.a.bates@gmail.com)
