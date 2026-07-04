// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Edith",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Edith",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
