/// Content-free outcome counts and timing for the active conversation.
package struct TranslationEvaluationSummary: Equatable, Sendable {
    /// Number of results accepted by the renderer handoff.
    package private(set) var rendererHandoffs = 0
    /// Longest time from caption finalization to a renderer handoff, including queue wait.
    package private(set) var longestHandoff: Duration?
    /// Nearest-rank p95 across successful handoffs, rounded up to the next 100 ms bound.
    /// Returns nil until a handoff succeeds. Omitted work is counted separately.
    package var rendererHandoffP95UpperBound: Duration? {
        handoffP95UpperBound(sampleCount: rendererHandoffs)
    }

    /// Denominator for completed handoffs and pre-playback omissions.
    /// Work still awaiting a result is measured once it resolves.
    package var resolvedEligibleUtterances: Int {
        rendererHandoffs + omissions.values.reduce(0, +)
    }

    /// P95 for resolved eligible work, with omissions ranked after all timed handoffs.
    /// Nil for an empty denominator or when the required rank is an omission.
    package var resolvedHandoffP95UpperBound: Duration? {
        handoffP95UpperBound(sampleCount: resolvedEligibleUtterances)
    }

    /// Numerator for resolved eligible utterances handed off within the five-second target.
    package var handoffsWithinFiveSeconds: Int {
        let targetBound = 5_000 / Self.bucketMilliseconds
        return handoffBounds.reduce(into: 0) { count, entry in
            if entry.key <= targetBound { count += entry.value }
        }
    }

    /// Counts of outcomes that were dropped before playback.
    package private(set) var omissions: [TranslationOmission.Reason: Int] = [:]

    private static let bucketMilliseconds: Int64 = 100
    // The pipeline expires work after ten seconds, so at most 101 bounds can occur.
    private var handoffBounds: [Int64: Int] = [:]

    private func handoffP95UpperBound(sampleCount: Int) -> Duration? {
        let rank = sampleCount - sampleCount / 20
        guard rank > 0, rank <= rendererHandoffs else { return nil }
        var cumulative = 0
        for bound in handoffBounds.keys.sorted() {
            cumulative += handoffBounds[bound, default: 0]
            if cumulative >= rank { return .milliseconds(bound * Self.bucketMilliseconds) }
        }
        return nil
    }

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
