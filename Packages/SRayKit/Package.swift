// swift-tools-version: 6.0
import PackageDescription

/// Shared native presentation and conversation modules.
let package = Package(
    name: "SRayKit",
    platforms: [.iOS(.v17), .visionOS(.v2), .macOS(.v14)],
    products: [.library(name: "SRayUI", targets: ["SRayUI"])],
    targets: [
        .target(name: "ConversationCore"),
        .target(name: "SRayUI", dependencies: ["ConversationCore"])
    ]
)
