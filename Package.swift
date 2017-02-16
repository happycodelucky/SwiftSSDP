import PackageDescription

let package = Package(
    name: "SwiftSSDP",
    dependencies: [
        .Package(url: "https://github.com/pryomoax/SwiftAbstractLogger.git", majorVersion: 0, minor: 1),
        .Package(url: "https://github.com/robbiehanson/CocoaAsyncSocket.git", majorVersion: 7, minor: 5),
        .Package(url: "https://github.com/nvzqz/Weak.git", majorVersion: 1)
    ]
)
