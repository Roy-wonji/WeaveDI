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
        .library(name: "WeaveDI", targets: ["WeaveDI"]),
        .library(name: "WeaveDICore", targets: ["WeaveDICore"]),
        .library(name: "WeaveDIMacroSupport", targets: ["WeaveDIMacroSupport"]),
        .library(name: "WeaveDIAppDI", targets: ["WeaveDIAppDI"]),
        .library(name: "WeaveDICompat", targets: ["WeaveDICompat"]),
        .library(name: "WeaveDINeedleCompat", targets: ["WeaveDINeedleCompat"]),
        .library(name: "WeaveDITCA", targets: ["WeaveDITCA"]),
        .library(name: "WeaveDIMonitoring", targets: ["WeaveDIMonitoring"]),
        .library(name: "WeaveDIOptimizations", targets: ["WeaveDIOptimizations"]),
        .executable(name: "Benchmarks", targets: ["Benchmarks"]),
        .executable(name: "WeaveDITools", targets: ["WeaveDITools"]),
    ],
    dependencies: [
        .package(url: "https://github.com/Roy-wonji/LogMacro.git", exact: "1.1.1"),
        .package(url: "https://github.com/apple/swift-docc-plugin.git", from: "1.4.5"),
        .package(
          url: "https://github.com/apple/swift-syntax.git", from: "600.0.0"),
        .package(
          url: "https://github.com/pointfreeco/swift-dependencies.git",
          from: "1.10.0"
        ),
    ],
    targets: [
        .target(
            name: "WeaveDI",
            dependencies: ["WeaveDICore"],
            path: "Sources/WeaveDI",
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ]
        ),
        .target(
            name: "WeaveDICore",
            dependencies: [
                .product(name: "LogMacro", package: "LogMacro")
            ],
            path: "Sources/WeaveDICore",
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ]
        ),
        .target(
            name: "WeaveDIMacroSupport",
            dependencies: [
                "WeaveDICore",
                "WeaveDIMacros"
            ],
            path: "Sources/WeaveDIMacroSupport"
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
        .target(
            name: "WeaveDIAppDI",
            dependencies: [
                "WeaveDICore",
                "WeaveDIOptimizations",
                "WeaveDIMonitoring",
                .product(name: "LogMacro", package: "LogMacro")
            ],
            path: "Sources/WeaveDIAppDI"
        ),
        .target(
            name: "WeaveDICompat",
            dependencies: ["WeaveDICore"],
            path: "Sources/WeaveDICompat"
        ),
        .target(
            name: "WeaveDINeedleCompat",
            dependencies: ["WeaveDICore"],
            path: "Sources/WeaveDINeedleCompat"
        ),
        .target(
            name: "WeaveDITCA",
            dependencies: [
                "WeaveDICore",
                "WeaveDINeedleCompat",
                .product(name: "Dependencies", package: "swift-dependencies")
            ],
            path: "Sources/WeaveDITCA"
        ),
        .target(
            name: "WeaveDIMonitoring",
            dependencies: [
                "WeaveDICore",
                "WeaveDINeedleCompat",
                "WeaveDIOptimizations"
            ],
            path: "Sources/WeaveDIMonitoring"
        ),
        .target(
            name: "WeaveDIOptimizations",
            dependencies: [
                "WeaveDICore",
                .product(name: "LogMacro", package: "LogMacro")
            ],
            path: "Sources/WeaveDIOptimizations"
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
            dependencies: [
                "WeaveDI",
                "WeaveDIOptimizations"
            ],
            path: "Sources/Benchmarks"
        ),
        .executableTarget(
            name: "WeaveDITools",
            dependencies: [
                "WeaveDI",
                "WeaveDINeedleCompat"
            ],
            path: "Sources/WeaveDITools"
        ),
    ],
    swiftLanguageModes: [.v6]
)
