// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ClawStudio",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "ClawStudio",
            path: "Sources/ClawStudio",
            resources: [
                .copy("../../Resources")
            ]
        )
    ]
)
