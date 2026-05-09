// swift-tools-version:6.0
//
//  Package.swift
//  SwiftSSDP
//
//  Copyright © 2017-2026 Paul Bates. All rights reserved.
//

import PackageDescription

let package = Package(
    name: "SwiftSSDP",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .tvOS(.v17),
    ],
    products: [
        .library(
            name: "SwiftSSDP",
            targets: ["SwiftSSDP"]
        ),
    ],
    targets: [
        .target(
            name: "SwiftSSDP",
            path: "Sources/SwiftSSDP",
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        .testTarget(
            name: "SwiftSSDPTests",
            dependencies: ["SwiftSSDP"],
            path: "Tests/SwiftSSDPTests",
            resources: [
                .copy("Fixtures"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
    ]
)
