// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WeaveDIApp",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    dependencies: [
        .package(
            url: "https://github.com/Roy-wonji/WeaveDI.git",
            from: "3.0.0"
        )
    ],
    targets: [
        .target(
            name: "WeaveDIApp",
            dependencies: ["WeaveDI"]
        )
    ]
)