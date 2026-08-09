// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Highlighter",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "Highlighter", type: .static, targets: ["Highlighter"])
    ],
    dependencies: [
        .package(path: "../EdithKit")
    ],
    targets: [
        .target(
            name: "Highlighter",
            dependencies: ["EdithKit"],
            resources: [.process("Resources")],
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
