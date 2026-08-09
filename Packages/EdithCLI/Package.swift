// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "EdithCLI",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "EdithCLI", type: .static, targets: ["EdithCLI"])
    ],
    dependencies: [
        .package(path: "../EdithKit"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0"),
    ],
    targets: [
        .target(
            name: "EdithCLI",
            dependencies: [
                "EdithKit",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
