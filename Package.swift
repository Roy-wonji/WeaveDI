// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "DiContainer",
    platforms: [.iOS(.v15), .macOS(.v12)],
    products: [
        .library(
            name: "DiContainer",
            targets: ["DiContainer"]),
    ],
    dependencies: [
      .package(url: "https://github.com/Roy-wonji/LogMacro.git", exact: "1.0.5")
    ],
    targets: [
        .target(
            name: "DiContainer",
            dependencies: [
              .product(name: "LogMacro", package: "LogMacro"),
            ]
        )
    ],
    swiftLanguageModes: [.version("5.10.0"), .version("6.0")]
)
