// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swift-zpl",
    platforms: [.iOS(.v17), .macOS(.v14), .tvOS(.v17), .watchOS(.v10), .visionOS(.v1)],
    products: [
        .library(name: "SwiftZPL", targets: ["SwiftZPL"]),
    ],
    targets: [
        .target(
            name: "SwiftZPL"
        ),
        .testTarget(
            name: "SwiftZPLTests",
            dependencies: ["SwiftZPL"]
        ),
    ]
)
