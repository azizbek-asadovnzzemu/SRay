// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SpeechReadinessProbe",
    platforms: [.iOS(.v17), .visionOS(.v2), .macOS(.v13)],
    products: [.library(name: "SpeechReadinessProbe", targets: ["SpeechReadinessProbe"])],
    targets: [
        .target(name: "SpeechReadinessProbe"),
        .testTarget(name: "SpeechReadinessProbeTests", dependencies: ["SpeechReadinessProbe"])
    ]
)
