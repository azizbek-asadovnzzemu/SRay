// swift-tools-version: 6.0
import PackageDescription

/// Shared native presentation and conversation modules.
let package = Package(
    name: "SRayKit",
    platforms: [.iOS(.v17), .visionOS(.v2), .macOS(.v14)],
    products: [
        .library(name: "SRayUI", targets: ["SRayUI"]),
        .library(name: "SpeechCore", targets: ["SpeechCore"]),
        .library(name: "SpeechPlatform", targets: ["SpeechPlatform"])
    ],
    targets: [
        .target(name: "SignMT"),
        .testTarget(name: "SignMTTests", dependencies: ["SignMT"]),
        .target(name: "ConversationCore"),
        .testTarget(name: "ConversationCoreTests", dependencies: ["ConversationCore"]),
        .target(name: "SpeechCore"),
        .target(name: "SpeechPlatform", dependencies: ["SpeechCore"]),
        .testTarget(name: "SpeechCoreTests", dependencies: ["SpeechCore"]),
        .target(name: "SRayUI", dependencies: ["ConversationCore"])
    ]
)
