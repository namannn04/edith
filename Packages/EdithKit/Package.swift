// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "EdithKit",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "EdithKit", type: .static, targets: ["EdithKit"])
    ],
    targets: [
        .target(
            name: "EdithKit",
            resources: [.process("Resources")],
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
