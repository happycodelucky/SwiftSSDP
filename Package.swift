// swift-tools-version:5.9
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
            path: "Sources/SwiftSSDP"
        ),
        .testTarget(
            name: "SwiftSSDPTests",
            dependencies: ["SwiftSSDP"],
            path: "Tests/SwiftSSDPTests",
            resources: [
                .copy("Fixtures"),
            ]
        ),
    ]
)
