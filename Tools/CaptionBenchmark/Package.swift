// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CaptionBenchmark",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "caption-benchmark", targets: ["CaptionBenchmarkCLI"])],
    targets: [
        .target(name: "CaptionMetrics"),
        .executableTarget(name: "CaptionBenchmarkCLI", dependencies: ["CaptionMetrics"]),
        .testTarget(name: "CaptionMetricsTests", dependencies: ["CaptionMetrics"]),
    ]
)
