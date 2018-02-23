import PackageDescription

let package = Package(
    name: "SwiftSSDP",
    dependencies: [
        .Package(url: "https://github.com/pryomoax/SwiftAbstractLogger.git", majorVersion: 0, minor: 3),
        .Package(url: "https://github.com/robbiehanson/CocoaAsyncSocket.git", majorVersion: 7, minor: 6),
        .Package(url: "https://github.com/nvzqz/Weak.git", majorVersion: 1)
    ]
)
