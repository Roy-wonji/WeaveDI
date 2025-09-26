// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DiContainerApp",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    dependencies: [
        .package(
            url: "https://github.com/Roy-wonji/DiContainer.git",
            from: "3.0.0"
        )
    ],
    targets: [
        .target(
            name: "DiContainerApp",
            dependencies: ["DiContainer"]
        )
    ]
)