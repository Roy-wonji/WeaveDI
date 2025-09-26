// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "WeaveDI",
    platforms: [
        .iOS(.v15),
        .macOS(.v14),
        .watchOS(.v8),
        .tvOS(.v15),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "WeaveDI",
            targets: ["WeaveDI"]
        ),
        .executable(
            name: "Benchmarks",
            targets: ["Benchmarks"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/Roy-wonji/LogMacro.git", branch: "main"),
        .package(url: "https://github.com/apple/swift-docc-plugin.git", from: "1.4.5"),
        .package(
          url: "https://github.com/apple/swift-syntax.git", from: "600.0.0"),
    ],
    targets: [
        .target(
            name: "WeaveDI",
            dependencies: [
                .product(name: "LogMacro", package: "LogMacro"),
                "WeaveDIMacros"
            ],
            path: "Sources",
            exclude: ["Benchmarks", "WeaveDIMacros"],
            resources: [
                .process("WeaveDI.docc")
            ],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ]
        ),
        .macro(
            name: "WeaveDIMacros",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax")
            ],
            path: "Sources/WeaveDIMacros"
        ),
        .testTarget(
            name: "WeaveDITests",
            dependencies: [
                "WeaveDI"
            ],
            path: "Tests/WeaveDITests"
        ),
        .executableTarget(
            name: "Benchmarks",
            dependencies: ["WeaveDI"],
            path: "Sources/Benchmarks"
        ),
    ],
    swiftLanguageModes: [.v6]
)
