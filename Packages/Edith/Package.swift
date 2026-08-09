// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Edith",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "Edith", type: .static, targets: ["Edith"])
    ],
    dependencies: [
        .package(path: "../EdithKit"),
        .package(path: "../Highlighter"),
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0"),
        .package(url: "https://github.com/migueldeicaza/SwiftTerm", from: "1.15.0"),
    ],
    targets: [
        .target(
            name: "Edith",
            dependencies: [
                "EdithKit",
                "Highlighter",
                .product(name: "Sparkle", package: "Sparkle"),
                .product(name: "SwiftTerm", package: "SwiftTerm"),
            ],
            resources: [.copy("Resources/appicon.png")],
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
