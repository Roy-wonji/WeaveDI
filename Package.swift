// swift-tools-version: 5.9
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
        .executable(
            name: "WeaveDITools",
            targets: ["WeaveDITools"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/Roy-wonji/LogMacro.git", exact: "1.1.1"),
        .package(url: "https://github.com/apple/swift-docc-plugin.git", from: "1.4.5"),
        .package(
          url: "https://github.com/apple/swift-syntax.git", from: "600.0.0"),
        .package(
          url: "https://github.com/pointfreeco/swift-dependencies.git",
          from: "1.2.0"
        ),
    ],
    targets: [
        .target(
            name: "WeaveDI",
            dependencies: [
                .product(name: "LogMacro", package: "LogMacro"),
                "WeaveDIMacros",
                .product(name: "Dependencies", package: "swift-dependencies")
            ],
            path: "Sources",
            exclude: ["Benchmarks", "WeaveDIMacros", "WeaveDITools"],
            resources: [
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
        .executableTarget(
            name: "WeaveDITools",
            dependencies: ["WeaveDI"],
            path: "Sources/WeaveDITools"
        ),
    ],
    swiftLanguageModes: [.v6]
)
