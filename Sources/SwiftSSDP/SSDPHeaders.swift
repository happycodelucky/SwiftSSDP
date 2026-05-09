//
//  SSDPHeaders.swift
//  SwiftSSDP
//
//  Copyright © 2017-2026 Paul Bates. All rights reserved.
//

import Foundation

/// A case-insensitive collection of SSDP headers.
///
/// Header names in SSDP are case-insensitive (they share HTTP/1.1's rules), but real-world
/// devices freely mix `CACHE-CONTROL`, `Cache-Control`, and `cache-control`. This wrapper
/// normalizes lookups so the parser and consumers can read by canonical key without juggling
/// case variants.
///
/// Values are stored as supplied; only lookup is normalized.
public struct SSDPHeaders: Sendable, Equatable {
    /// Storage indexed by uppercase keys (the SSDP/UPnP canonical form).
    private var storage: [String: String]

    /// Creates an empty header set.
    public init() {
        self.storage = [:]
    }

    /// Creates a header set from a dictionary of raw key/value pairs.
    ///
    /// If the input contains multiple keys that compare equal case-insensitively, the
    /// last one encountered wins.
    public init(_ pairs: [String: String]) {
        var normalized: [String: String] = [:]
        normalized.reserveCapacity(pairs.count)
        for (k, v) in pairs {
            normalized[k.uppercased()] = v
        }
        self.storage = normalized
    }

    /// Case-insensitive lookup / mutation by header name.
    public subscript(key: String) -> String? {
        get { storage[key.uppercased()] }
        set { storage[key.uppercased()] = newValue }
    }

    /// True if no headers are set.
    public var isEmpty: Bool { storage.isEmpty }

    /// Number of headers in the set.
    public var count: Int { storage.count }

    /// All header names, in their normalized (uppercase) form.
    public var keys: Dictionary<String, String>.Keys { storage.keys }

    /// All header values.
    public var values: Dictionary<String, String>.Values { storage.values }

    /// The underlying dictionary (uppercase-keyed) for advanced use.
    public var asDictionary: [String: String] { storage }

    /// Returns a copy of the header set with the given keys removed (case-insensitive).
    func removing(_ keys: [String]) -> SSDPHeaders {
        var copy = self
        for k in keys {
            copy.storage.removeValue(forKey: k.uppercased())
        }
        return copy
    }
}

extension SSDPHeaders: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, String)...) {
        self.init(Dictionary(uniqueKeysWithValues: elements))
    }
}

extension SSDPHeaders: Sequence {
    public func makeIterator() -> Dictionary<String, String>.Iterator {
        storage.makeIterator()
    }
}
