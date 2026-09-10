// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DeskCam",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "DeskCam", targets: ["DeskCam"]),
        .library(name: "DeskCamCore", targets: ["DeskCamCore"]),
    ],
    targets: [
        .target(
            name: "DeskCamCore",
            path: "Sources/DeskCamCore",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(
            name: "DeskCam",
            dependencies: ["DeskCamCore"],
            path: "Sources/DeskCam",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "DeskCamCoreTests",
            dependencies: ["DeskCamCore"],
            path: "Tests/DeskCamCoreTests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
