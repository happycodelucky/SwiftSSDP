// swift-tools-version:5.9
//
//  Package.swift
//  ssdp-demo
//
//  CLI demo for SwiftSSDP — `ssdp-demo search <target>` and `ssdp-demo listen`.
//

import PackageDescription

let package = Package(
    name: "ssdp-demo",
    platforms: [
        .macOS(.v14),
    ],
    dependencies: [
        // Local path-dep back to the parent SwiftSSDP package.
        .package(name: "SwiftSSDP", path: "../.."),
    ],
    targets: [
        .executableTarget(
            name: "ssdp-demo",
            dependencies: ["SwiftSSDP"],
            path: "Sources/ssdp-demo"
        ),
    ]
)
