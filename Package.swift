// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MustDo",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "MustDoCore",
            targets: ["MustDoCore"]
        ),
        .executable(
            name: "MustDo",
            targets: ["MustDo"]
        )
    ],
    targets: [
        .target(
            name: "MustDoCore"
        ),
        .executableTarget(
            name: "MustDo",
            dependencies: ["MustDoCore"]
        ),
        .testTarget(
            name: "MustDoTests",
            dependencies: ["MustDoCore"]
        )
    ]
)
