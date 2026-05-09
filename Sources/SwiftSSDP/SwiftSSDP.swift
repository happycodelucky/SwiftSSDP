//
//  SwiftSSDP.swift
//  SwiftSSDP
//
//  Copyright © 2017-2026 Paul Bates. All rights reserved.
//

import Foundation

/// Top-level metadata for the SwiftSSDP library.
///
/// This namespace exposes runtime-introspectable information about the library version.
/// Useful for diagnostic logging in host apps, and updated automatically by the release
/// workflow when a new version is tagged.
public enum SwiftSSDP {
    /// The library's semantic version, matching the most recent published git tag.
    ///
    /// > Note: This constant is rewritten by `.github/workflows/release.yml` whenever a
    /// > release is published. Do not edit it by hand outside of that workflow.
    public static let version = "2.0.0"
}
