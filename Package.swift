// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swift-zpl",
    platforms: [.iOS(.v17), .macOS(.v14), .tvOS(.v17), .watchOS(.v10), .visionOS(.v1)],
    products: [
        .library(name: "SwiftZPL", targets: ["SwiftZPL"]),
        .library(name: "SwiftZPLNetwork", targets: ["SwiftZPLNetwork"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.65.0"),
    ],
    targets: [
        // Pure ZPL generation: no dependencies, no I/O.
        .target(name: "SwiftZPL"),
        // TCP transport and status queries, on SwiftNIO.
        .target(
            name: "SwiftZPLNetwork",
            dependencies: [
                "SwiftZPL",
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio"),
                .product(name: "NIOConcurrencyHelpers", package: "swift-nio"),
            ]
        ),
        .testTarget(
            name: "SwiftZPLTests",
            dependencies: ["SwiftZPL"]
        ),
        .testTarget(
            name: "SwiftZPLNetworkTests",
            dependencies: [
                "SwiftZPL",
                "SwiftZPLNetwork",
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio"),
                .product(name: "NIOConcurrencyHelpers", package: "swift-nio"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
