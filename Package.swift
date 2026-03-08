// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "StickyMVP",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "StickyMVPCore",
            targets: ["StickyMVPCore"]
        ),
        .executable(
            name: "StickyMVP",
            targets: ["StickyMVP"]
        )
    ],
    targets: [
        .target(
            name: "StickyMVPCore"
        ),
        .executableTarget(
            name: "StickyMVP",
            dependencies: ["StickyMVPCore"]
        ),
        .testTarget(
            name: "StickyMVPTests",
            dependencies: ["StickyMVPCore"]
        )
    ]
)
