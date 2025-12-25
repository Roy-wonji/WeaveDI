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
        // 🎯 메인 라이브러리 - 모든 기능 통합!
        .library(name: "WeaveDI", targets: ["WeaveDI"]),

        // 📝 매크로 (선택적)
        .library(name: "WeaveDIMacros", targets: ["WeaveDIMacros"]),

        // 🔄 TCA 통합 (v4.1에서 재구현 예정)
        // .library(name: "WeaveDITCA", targets: ["WeaveDITCA"]),
    ],
    dependencies: [
        .package(url: "https://github.com/Roy-wonji/LogMacro.git", exact: "1.1.1"),
        .package(url: "https://github.com/apple/swift-docc-plugin.git", from: "1.4.5"),
        .package(
          url: "https://github.com/apple/swift-syntax.git", from: "600.0.0"),
        // .package(
        //   url: "https://github.com/pointfreeco/swift-dependencies.git",
        //   from: "1.10.0"
        // ),
    ],
    targets: [
        // 🎯 메인 타겟 - 모든 핵심 기능 통합!
        .target(
            name: "WeaveDI",
            dependencies: [
                "WeaveDICore",
                "WeaveDIMacros",
                .product(name: "LogMacro", package: "LogMacro")
            ],
            path: "Sources/WeaveDI",
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ]
        ),

        // 🎯 Core 기능 타겟
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

        // 📝 매크로 타겟
        .macro(
            name: "WeaveDIMacros",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax")
            ]
        ),

        // 🔄 TCA 통합 타겟 (v4.1에서 재구현 예정)
        // .target(
        //     name: "WeaveDITCA",
        //     dependencies: [
        //         "WeaveDI",
        //         .product(name: "Dependencies", package: "swift-dependencies")
        //     ]
        // ),
        // 🧪 테스트 타겟
        .testTarget(
            name: "WeaveDITests",
            dependencies: ["WeaveDI"]
        ),

        // 📊 벤치마크 타겟 (성능 측정)
        .executableTarget(
            name: "Benchmarks",
            dependencies: ["WeaveDI"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
