// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "DiContainer",
    platforms: [
        .iOS(.v15), 
        .macOS(.v14), 
        .watchOS(.v8), 
        .tvOS(.v15),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "DiContainer",
            targets: ["DiContainer"]
        ),
        .executable(
            name: "Benchmarks",
            targets: ["Benchmarks"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/Roy-wonji/LogMacro.git", from: "1.1.0"),
        .package(url: "https://github.com/apple/swift-docc-plugin.git", from: "1.4.5"),
    ],
    targets: [
        .target(
            name: "DiContainer",
            dependencies: [
                .product(name: "LogMacro", package: "LogMacro"),
            ],
            path: "Sources",
            exclude: ["Benchmarks"],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "DiContainerTests",
            dependencies: [
                "DiContainer"
            ],
            path: "Tests/DiContainerTests"
        ),
        .executableTarget(
            name: "Benchmarks",
            dependencies: ["DiContainer"],
            path: "Sources/Benchmarks"
        )
    ],
    swiftLanguageModes: [.v6]
)
