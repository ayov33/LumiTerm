// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "AICompanion",
    platforms: [.macOS(.v13)],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "AICompanion",
            dependencies: [],
            path: "Sources",
            resources: [
                .copy("Resources")
            ]
        )
    ]
)
