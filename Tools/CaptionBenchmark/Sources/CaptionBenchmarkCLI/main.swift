import CaptionMetrics
import Darwin
import Foundation

do {
    let source = FileHandle.standardInput
    let maximumBytes = 8 * 1_024 * 1_024
    var bytes = Data()
    while let chunk = try source.read(upToCount: 65_536), !chunk.isEmpty {
        guard chunk.count <= maximumBytes - bytes.count else { throw CaptionBenchmarkError.exceedsBudget }
        bytes.append(chunk)
    }
    let batch = try JSONDecoder().decode(CaptionBenchmarkInput.self, from: bytes)
    let report = try CaptionBenchmark.score(batch)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let encoded = try encoder.encode(report)
    try FileHandle.standardOutput.write(contentsOf: encoded + Data([10]))
} catch {
    // Some decoding errors carry pieces of the original input. Never print them.
    try? FileHandle.standardError.write(contentsOf: Data("Unable to score input. Check the benchmark schema and limits.\n".utf8))
    exit(1)
}
