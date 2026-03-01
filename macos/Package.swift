// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "flutter_story_encoder",
    platforms: [
        .macOS(.v11)
    ],
    products: [
        .library(name: "flutter-story-encoder", targets: ["flutter_story_encoder"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "flutter_story_encoder",
            dependencies: [],
            path: "Classes",
            resources: []
        )
    ]
)
