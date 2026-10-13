// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "WhatSoccerPlayerAreYa",
    platforms: [.macOS(.v14)],
    targets: [
        .target(
            name: "SoccerCore",
            resources: [.copy("Resources/players.csv")]
        ),
        .executableTarget(
            name: "WhatSoccerPlayerAreYa",
            dependencies: ["SoccerCore"]
        ),
        .testTarget(
            name: "SoccerCoreTests",
            dependencies: ["SoccerCore"]
        ),
    ]
)
