// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "LumiTerm",
    platforms: [.macOS(.v13)],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "LumiTerm",
            dependencies: [],
            path: "Sources",
            resources: [
                .copy("Resources")
            ]
        ),
        .testTarget(
            name: "LumiTermTests",
            dependencies: [],
            path: "Tests"
        )
    ]
)
