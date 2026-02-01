// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftGrib",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
        .tvOS(.v16),
        .watchOS(.v9),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "SwiftGrib",
            targets: ["SwiftGrib"]
        ),
        .executable(
            name: "SwiftGribDemo",
            targets: ["SwiftGribDemo"]
        ),
    ],
    targets: [
        .target(
            name: "SwiftGrib",
            dependencies: [],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .executableTarget(
            name: "SwiftGribDemo",
            dependencies: ["SwiftGrib"],
            resources: [
                .copy("Resources")
            ]
        ),
        .testTarget(
            name: "SwiftGribTests",
            dependencies: ["SwiftGrib"],
            resources: [
                .copy("Resources")
            ]
        ),
    ]
)
