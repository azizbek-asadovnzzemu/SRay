/// Content-free outcome counts and timing for the active conversation.
package struct TranslationEvaluationSummary: Equatable, Sendable {
    /// Number of results accepted by the renderer handoff.
    package private(set) var rendererHandoffs = 0
    /// Longest time from caption finalization to a renderer handoff, including queue wait.
    package private(set) var longestHandoff: Duration?
    /// Nearest-rank p95 across successful handoffs, rounded up to the next 100 ms bound.
    /// Returns nil until a handoff succeeds. Omitted work is counted separately.
    package var rendererHandoffP95UpperBound: Duration? {
        guard rendererHandoffs > 0 else { return nil }
        let rank = rendererHandoffs - rendererHandoffs / 20
        var cumulative = 0
        for bound in handoffBounds.keys.sorted() {
            cumulative += handoffBounds[bound, default: 0]
            if cumulative >= rank { return .milliseconds(bound * Self.bucketMilliseconds) }
        }
        return nil
    }

    /// Counts of outcomes that were dropped before playback.
    package private(set) var omissions: [TranslationOmission.Reason: Int] = [:]

    private static let bucketMilliseconds: Int64 = 100
    // The pipeline expires work after ten seconds, so at most 101 bounds can occur.
    private var handoffBounds: [Int64: Int] = [:]

    /// Records a successful live handoff. Replay is independent of translation.
    mutating func recordHandoff(after latency: Duration) {
        rendererHandoffs += 1
        longestHandoff = max(longestHandoff ?? latency, latency)
        let (seconds, attoseconds) = latency.components
        let bucketsPerSecond = 1_000 / Self.bucketMilliseconds
        let bucketAttoseconds = Duration.milliseconds(Self.bucketMilliseconds).components.attoseconds
        let upperBound = seconds * bucketsPerSecond + (attoseconds + bucketAttoseconds - 1) / bucketAttoseconds
        handoffBounds[upperBound, default: 0] += 1
    }

    /// Records an outcome even if the caption row has already been evicted.
    mutating func recordOmission(_ reason: TranslationOmission.Reason) {
        omissions[reason, default: 0] += 1
    }
}
