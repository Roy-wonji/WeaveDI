# Package.swift Draft (Targets/Products Split)

This is a draft proposal for target/module separation. It is not applied to
`Package.swift` yet. Paths marked as TODO indicate new folders or file moves
needed to make the split compile.

```swift
// swift-tools-version: 6.1

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
    .library(name: "WeaveDITCA", targets: ["WeaveDITCA"]),
    .library(name: "WeaveDIMonitoring", targets: ["WeaveDIMonitoring"]),
    .library(name: "WeaveDIOptimizations", targets: ["WeaveDIOptimizations"]),
    .executable(name: "Benchmarks", targets: ["Benchmarks"]),
    .executable(name: "WeaveDITools", targets: ["WeaveDITools"])
  ],
  dependencies: [
    .package(url: "https://github.com/Roy-wonji/LogMacro.git", exact: "1.1.1"),
    .package(url: "https://github.com/apple/swift-docc-plugin.git", from: "1.4.5"),
    .package(url: "https://github.com/apple/swift-syntax.git", from: "600.0.0"),
    .package(url: "https://github.com/pointfreeco/swift-dependencies.git", from: "1.10.0")
  ],
  targets: [
    // Umbrella -> Core only (import WeaveDI = Core)
    .target(
      name: "WeaveDI",
      dependencies: ["WeaveDICore"],
      path: "Sources/WeaveDI",
      swiftSettings: [.enableUpcomingFeature("StrictConcurrency")]
    ),

    // Core (register/resolve/lifetime/@Injected/@Factory/bootstrap)
    .target(
      name: "WeaveDICore",
      dependencies: [
        .product(name: "LogMacro", package: "LogMacro")
      ],
      path: "Sources/WeaveDICore", // TODO: move Core sources here
      swiftSettings: [.enableUpcomingFeature("StrictConcurrency")]
    ),

    // Macros (declaration) -> Core only
    .target(
      name: "WeaveDIMacroSupport",
      dependencies: ["WeaveDICore"],
      path: "Sources/WeaveDIMacroSupport" // TODO
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

    // AppDI (optional)
    .target(
      name: "WeaveDIAppDI",
      dependencies: ["WeaveDICore"],
      path: "Sources/WeaveDIAppDI" // TODO
    ),

    // Legacy wrappers (optional)
    .target(
      name: "WeaveDICompat",
      dependencies: ["WeaveDICore"],
      path: "Sources/WeaveDICompat" // TODO
    ),

    // TCA integration (optional)
    .target(
      name: "WeaveDITCA",
      dependencies: [
        "WeaveDICore",
        .product(name: "Dependencies", package: "swift-dependencies")
      ],
      path: "Sources/WeaveDITCA" // TODO
    ),

    // Monitoring (optional)
    .target(
      name: "WeaveDIMonitoring",
      dependencies: ["WeaveDICore"],
      path: "Sources/WeaveDIMonitoring" // TODO
    ),

    // Optimizations (optional)
    .target(
      name: "WeaveDIOptimizations",
      dependencies: ["WeaveDICore"],
      path: "Sources/WeaveDIOptimizations" // TODO
    ),

    .testTarget(
      name: "WeaveDITests",
      dependencies: ["WeaveDI"],
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
    )
  ],
  swiftLanguageModes: [.v6]
)
```
