// swift-tools-version: 6.0
import PackageDescription

/// Shared native presentation and conversation modules.
let package = Package(
    name: "SRayKit",
    platforms: [.iOS(.v17), .visionOS(.v2), .macOS(.v14)],
    products: [
        .library(name: "PoseCore", targets: ["PoseCore"]),
        .library(name: "PosePlayback", targets: ["PosePlayback"]),
        .library(name: "SRayUI", targets: ["SRayUI"]),
        .library(name: "SpeechCore", targets: ["SpeechCore"]),
        .library(name: "SpeechPlatform", targets: ["SpeechPlatform"])
    ],
    targets: [
        .target(name: "PoseCore"),
        .target(name: "PosePlayback", dependencies: ["PoseCore"]),
        .testTarget(name: "PosePlaybackTests", dependencies: ["PoseCore", "PosePlayback"]),
        .testTarget(name: "PoseCoreTests", dependencies: ["PoseCore"]),
        .target(name: "SignMT", dependencies: ["PoseCore"]),
        .testTarget(name: "SignMTTests", dependencies: ["PoseCore", "SignMT"]),
        .target(name: "ConversationCore", dependencies: ["SpeechCore"]),
        .testTarget(name: "ConversationCoreTests", dependencies: ["ConversationCore", "SpeechCore"]),
        .target(name: "SpeechCore"),
        .target(name: "SpeechPlatform", dependencies: ["SpeechCore"]),
        .testTarget(name: "SpeechCoreTests", dependencies: ["SpeechCore"]),
        .target(name: "SRayUI", dependencies: ["ConversationCore", "PoseCore", "PosePlayback", "SpeechCore", "SpeechPlatform"])
    ]
)
