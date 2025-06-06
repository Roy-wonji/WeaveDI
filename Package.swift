// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "DiContainer",
    platforms: [.iOS(.v15), .macOS(.v14)],
    products: [
        .library(
            name: "DiContainer",
            targets: ["DiContainer"]),
    ],
    dependencies: [
      .package(url: "https://github.com/Roy-wonji/LogMacro.git", exact: "1.0.7"),
      .package(url: "https://github.com/apple/swift-docc-plugin.git", exact: "1.4.4"),
    ],
    targets: [
        .target(
            name: "DiContainer",
            dependencies: [
              .product(name: "LogMacro", package: "LogMacro"),
            ]
        )
    ],
)
