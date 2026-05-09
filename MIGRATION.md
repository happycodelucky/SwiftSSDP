# Migrating from SwiftSSDP 0.5.x → 2.0.0

v2.0.0 is a clean break — the API is async/await, the delegate protocol is gone, and the third-party dependencies (CocoaAsyncSocket, SwiftAbstractLogger, Weak) are removed in favor of `Network.framework` + `os.Logger`. This document walks the migration step by step.

## Tl;dr

| Before (0.5.x) | After (2.0.0) |
|---|---|
| `SSDPDiscoveryDelegate` protocol | `for try await … in discovery.search(...)` |
| `SSDPDiscoverySession` | `AsyncThrowingStream` lifecycle |
| `SSDPDiscovery.defaultDiscovery` singleton | `let discovery = SSDPDiscovery()` |
| Combine-style or callback delegate | Native async/await |
| (no NOTIFY support) | `for try await n in discovery.notifications()` |

## Step-by-step

### 1. Replace the delegate with `for try await`

**Before:**

```swift
class DeviceDiscovery: SSDPDiscoveryDelegate {
    var session: SSDPDiscoverySession?

    func searchForDevices() {
        let request = SSDPMSearchRequest(
            delegate: self,
            searchTarget: .deviceType(schema: SSDPSearchTarget.upnpOrgSchema,
                                      deviceType: "ZonePlayer", version: 1)
        )
        session = try! SSDPDiscovery.defaultDiscovery.startDiscovery(
            request: request, timeout: 10.0)
    }

    func discoveredDevice(response: SSDPMSearchResponse,
                          session: SSDPDiscoverySession) {
        print("Found \(response)")
    }
    func discoveredService(response: SSDPMSearchResponse,
                           session: SSDPDiscoverySession) {}
    func closedSession(_ session: SSDPDiscoverySession) {}
}
```

**After:**

```swift
class DeviceDiscovery {
    let discovery = SSDPDiscovery()

    func searchForDevices() async throws {
        let target: SSDPSearchTarget = .deviceType(
            schema: .upnpOrgSchema, deviceType: "ZonePlayer", version: 1)

        for try await response in discovery.search(for: target, timeout: 10) {
            print("Found \(response)")
        }
    }
}
```

The async function naturally captures the lifecycle — when it returns (or throws), the search ends.

### 2. `SSDPDiscoverySession` is gone

The session abstraction collapsed into the `AsyncThrowingStream`. Cancellation is automatic — break the `for try await` loop, return from the enclosing function, or cancel the parent `Task`. The library cleans up the underlying socket.

If you previously stored the session as `var session: SSDPDiscoverySession?` and called `session?.close()` to stop, you now hold a `Task<Void, Error>` (or just structured-concurrency scope) and call `task.cancel()`:

```swift
var searchTask: Task<Void, Error>?

func searchForDevices() {
    searchTask = Task {
        for try await response in discovery.search(for: .rootDevice) {
            // ...
        }
    }
}

func stopSearching() {
    searchTask?.cancel()
}
```

### 3. The `defaultDiscovery` singleton is removed

Instantiate your own. `SSDPDiscovery()` is cheap.

```swift
// Before
let discovery = SSDPDiscovery.defaultDiscovery

// After
let discovery = SSDPDiscovery()    // hold this in your AppDelegate, @State, or an Observable
```

If you really want a single shared instance app-wide, set one up yourself:

```swift
extension SSDPDiscovery {
    static let shared = SSDPDiscovery()
}
```

### 4. `SSDPMSearchRequest` no longer takes a `delegate`

The `delegate:` parameter is gone — there's no delegate to plumb anymore.

```swift
// Before
let request = SSDPMSearchRequest(delegate: self, searchTarget: target)

// After
let request = SSDPMSearchRequest(searchTarget: target)
```

`maxWait` and `otherHeaders` parameters are unchanged.

### 5. NOTIFY listening is now possible

This was the headline missing feature. v2.0 implements it:

```swift
for try await notification in discovery.notifications() {
    switch notification {
    case .alive(let ad):    print("→ \(ad.usn)")
    case .byebye(let ad):   print("← \(ad.usn)")
    case .update(let ad):   print("⟳ \(ad.usn)")
    }
}
```

**iOS/iPadOS/tvOS apps need the `com.apple.developer.networking.multicast` entitlement** — see the README's *iOS multicast entitlement* section.

### 6. Renames (typo fixes)

These public symbols had typos in 0.5.x; v2.0 spells them correctly:

| Old | New |
|---|---|
| `SSDPMSearchRequest.messsageHeader` (3 s's) | `SSDPMSearchRequest.messageHeader` |
| `SSDPMessageAnnoucement` (missing 'n') | `SSDPMessageAnnouncement` |

### 7. `SSDPMSearchResponse.cacheControl` semantic change

In 0.5.x this was a `Date?` computed at parse time — useless after a few seconds in a long-running process, and broken by a `× 1000` bug that always made it 1000× too large.

In v2.0 it's the raw `max-age` in seconds:

```swift
// Before — Date?, possibly garbage
if let expires = response.cacheControl, expires < Date() { /* stale */ }

// After — TimeInterval? in seconds
if let maxAge = response.cacheControl {
    let expires = receivedAt.addingTimeInterval(maxAge)
    if expires < Date() { /* stale */ }
}
```

If you depended on the old (buggy) behavior, replace it with the snippet above.

### 8. `SSDPDiscovery.startDiscovery` and `stopAllDiscovery` are gone

Replaced by the per-call streams. There's no global "stop everything" — cancel individual `Task`s, or scope them in `withTaskGroup` and cancel the group.

### 9. Headers: `SSDPHeaders` is now a struct, not a typealias

`SSDPHeaders` is now a case-insensitive `struct` wrapper around `[String: String]`, conforming to `ExpressibleByDictionaryLiteral`:

```swift
// Before — plain dictionary
let headers: SSDPHeaders = ["X-Custom": "value"]   // type was [String: String]

// After — same call site works thanks to ExpressibleByDictionaryLiteral
let headers: SSDPHeaders = ["X-Custom": "value"]   // type is SSDPHeaders
```

If you held the dictionary directly: use `headers.asDictionary` to get `[String: String]`.

### 10. NOTIFY payload type — `SSDPAdvertisement`

NOTIFY messages parse into `SSDPAdvertisement` (not `SSDPMSearchResponse`). The fields differ slightly:

- `notificationTarget` (NT header), not `searchTarget` (ST header)
- No `ext` field (NOTIFY messages have no `EXT`)
- `location` is **optional** — `byebye` notifications omit it
- `bootID`, `configID`, `nextBootID` (UPnP 1.1) surfaced as typed `Int?` fields

### 11. Logging

`SwiftAbstractLogger` is gone. The library now uses `os.Logger`. Filter logs in Console.app or `log stream` by subsystem `com.pryomoax.SwiftSSDP`. Categories: `discovery`, `transport`, `listener`, `parser`.

```sh
log stream --predicate 'subsystem == "com.pryomoax.SwiftSSDP"' --level debug
```

### 12. Removed dependencies

You can drop these from your `Package.swift` if SwiftSSDP was the only consumer:

- `CocoaAsyncSocket`
- `SwiftAbstractLogger`
- `Weak` (the nvzqz/Weak.swift package)

### 13. Platform requirements changed

| | Before | After |
|---|---|---|
| Swift | 4.0+ | 5.9+ |
| iOS | 10.0+ | 17.0+ |
| macOS | (project-target only) | 14.0+ |
| tvOS | (project-target only) | 17.0+ |
| watchOS | listed in project | **dropped** (multicast unavailable) |

The platform bump is driven by:
- `Network.framework`'s `NWConnectionGroup` + `NWMulticastGroup` (iOS 14+, but matured significantly in 17).
- Modern `AsyncThrowingStream.makeStream(of:bufferingPolicy:)` ergonomics.
- `os.Logger` improvements.
- `Task.sleep(for: Duration)`.

## If you can't migrate yet

The 0.5.3 release is still tagged in this repository; pin to it:

```swift
.package(url: "https://github.com/pryomoax/SwiftSSDP.git", .exact("0.5.3"))
```

Note that 0.5.x is unmaintained and its `cacheControl` and `DATE` parsing remain broken.
