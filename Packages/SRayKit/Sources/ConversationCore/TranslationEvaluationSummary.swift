/// Content-free outcome counts and timing for the active conversation.
package struct TranslationEvaluationSummary: Equatable, Sendable {
    /// Number of results accepted by the renderer handoff.
    package private(set) var rendererHandoffs = 0
    /// Longest time from caption finalization to a renderer handoff, including queue wait.
    package private(set) var longestHandoff: Duration?
    /// Counts of outcomes that were dropped before playback.
    package private(set) var omissions: [TranslationOmission.Reason: Int] = [:]

    /// Records a successful live handoff. Replay is independent of translation.
    mutating func recordHandoff(after latency: Duration) {
        rendererHandoffs += 1
        longestHandoff = max(longestHandoff ?? latency, latency)
    }

    /// Records an outcome even if the caption row has already been evicted.
    mutating func recordOmission(_ reason: TranslationOmission.Reason) {
        omissions[reason, default: 0] += 1
    }
}
