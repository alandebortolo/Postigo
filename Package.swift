// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Postigo",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Postigo", targets: ["Postigo"]),
        .library(name: "PostigoCore", targets: ["PostigoCore"]),
    ],
    targets: [
        .target(
            name: "PostigoCore",
            path: "Sources/PostigoCore",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(
            name: "Postigo",
            dependencies: ["PostigoCore"],
            path: "Sources/Postigo",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "PostigoCoreTests",
            dependencies: ["PostigoCore"],
            path: "Tests/PostigoCoreTests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
