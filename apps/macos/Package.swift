// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Edith",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0")
    ],
    targets: [
        .target(
            name: "EdithKit",
            resources: [.process("Resources")],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(
            name: "Edith",
            dependencies: [
                "EdithKit",
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            resources: [.copy("Resources/appicon.png")],
            swiftSettings: [.swiftLanguageMode(.v5)],
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks",
                ])
            ]
        ),
        .executableTarget(
            name: "EdithHelper",
            dependencies: ["EdithKit"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(
            name: "EdithInstaller",
            dependencies: ["EdithKit"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "EdithTests",
            dependencies: ["Edith", "EdithKit", "EdithHelper", "EdithInstaller"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
