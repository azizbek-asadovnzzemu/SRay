import Foundation

/// Scoring inputs for one corpus condition after applying its approved normalization.
public struct CaptionBenchmarkInput: Decodable, Sendable {
    /// One utterance's reference and recognized token arrays. A nil hypothesis records failure.
    public struct Utterance: Decodable, Sendable {
        public let reference: [String]
        public let hypothesis: [String]?
    }

    /// Monotonic milliseconds from one shared measurement origin.
    public struct WordObservation: Decodable, Sendable {
        public let spokenWordEndMilliseconds: Int
        /// Nil if a corresponding correct partial was never visible.
        public let firstVisiblePartialMilliseconds: Int?
    }

    /// One cold-start attempt measured on its own monotonic clock.
    public struct ColdStartObservation: Decodable, Sendable {
        public let startActionMilliseconds: Int
        /// Nil when the attempt never produced a visible caption.
        public let firstVisibleCaptionMilliseconds: Int?
    }

    public let utterances: [Utterance]
    public let wordObservations: [WordObservation]
    public let coldStarts: [ColdStartObservation]?

    init(utterances: [Utterance], wordObservations: [WordObservation], coldStarts: [ColdStartObservation]? = nil) {
        self.utterances = utterances
        self.wordObservations = wordObservations
        self.coldStarts = coldStarts
    }
}

/// Aggregate results with no transcript text, utterance IDs, or individual timestamps.
public struct CaptionBenchmarkReport: Encodable, Equatable, Sendable {
    /// Cold-start timing scored separately from word-aligned partial latency.
    public struct ColdStart: Encodable, Equatable, Sendable {
        public let attempts: Int
        public let missingCaptions: Int
        /// Nil if the required rank was a missing caption or the batch was empty.
        public let allAttemptP95Milliseconds: Int?
        /// P95 conditioned on the appearance of a caption.
        public let displayedCaptionP95Milliseconds: Int?
    }

    public let referenceWords: Int
    public let substitutions: Int
    public let deletions: Int
    public let insertions: Int
    public let recognitionFailures: Int
    /// Ratio of total edit operations to reference words. Nil without reference words.
    public let wordErrorRate: Double?
    public let observedWords: Int
    public let missingPartials: Int
    /// Nearest-rank p95 of signed delays across all words, ranking missing partials last.
    /// Nil means the percentile is unavailable or belongs to the missing results.
    public let allWordP95Milliseconds: Int?
    /// A separate percentile conditioned on a correct partial appearing.
    public let displayedWordP95Milliseconds: Int?
    /// Separate aggregate when cold-start observations were supplied.
    public let coldStart: ColdStart?
}

/// Content-free failures for invalid or oversized benchmark inputs.
public enum CaptionBenchmarkError: Error, Equatable {
    case exceedsBudget
    case invalidTokens
    case invalidTiming
}

/// Scores token accuracy and visible caption latency without performing recognition.
public enum CaptionBenchmark {
    /// Returns one corpus-weighted aggregate. Failing recognitions count as reference deletions.
    public static func score(_ input: CaptionBenchmarkInput) throws -> CaptionBenchmarkReport {
        guard input.utterances.count <= 10_000, input.wordObservations.count <= 100_000 else {
            throw CaptionBenchmarkError.exceedsBudget
        }

        var total = Edits()
        var words = 0
        var failures = 0
        var remainingComparisons = 10_000_000
        for utterance in input.utterances {
            let reference = utterance.reference
            let hypothesis = utterance.hypothesis ?? []
            guard reference.count <= 512, hypothesis.count <= 512 else {
                throw CaptionBenchmarkError.exceedsBudget
            }
            guard reference.allSatisfy(isValidToken), hypothesis.allSatisfy(isValidToken) else {
                throw CaptionBenchmarkError.invalidTokens
            }
            remainingComparisons -= reference.count * hypothesis.count
            guard remainingComparisons >= 0 else { throw CaptionBenchmarkError.exceedsBudget }
            words += reference.count
            if utterance.hypothesis == nil { failures += 1 }
            let result = align(reference: reference, hypothesis: hypothesis)
            total.substitutions += result.substitutions
            total.deletions += result.deletions
            total.insertions += result.insertions
        }

        var delays: [Int] = []
        for word in input.wordObservations {
            let end = word.spokenWordEndMilliseconds
            guard end >= 0 else { throw CaptionBenchmarkError.invalidTiming }
            guard let visible = word.firstVisiblePartialMilliseconds else { continue }
            guard visible >= 0 else { throw CaptionBenchmarkError.invalidTiming }
            delays.append(visible - end)
        }
        delays.sort()
        let observed = input.wordObservations.count

        return CaptionBenchmarkReport(
            referenceWords: words, substitutions: total.substitutions, deletions: total.deletions,
            insertions: total.insertions, recognitionFailures: failures,
            wordErrorRate: words == 0 ? nil : Double(total.count) / Double(words),
            observedWords: observed, missingPartials: observed - delays.count,
            allWordP95Milliseconds: p95(delays, sampleCount: observed),
            displayedWordP95Milliseconds: p95(delays, sampleCount: delays.count),
            coldStart: try input.coldStarts.map(scoreColdStarts)
        )
    }

    private static func scoreColdStarts(
        _ observations: [CaptionBenchmarkInput.ColdStartObservation]
    ) throws -> CaptionBenchmarkReport.ColdStart {
        guard observations.count <= 10_000 else { throw CaptionBenchmarkError.exceedsBudget }
        var delays: [Int] = []
        for observation in observations {
            let start = observation.startActionMilliseconds
            guard start >= 0 else { throw CaptionBenchmarkError.invalidTiming }
            guard let visible = observation.firstVisibleCaptionMilliseconds else { continue }
            guard visible >= start else { throw CaptionBenchmarkError.invalidTiming }
            delays.append(visible - start)
        }
        delays.sort()
        return CaptionBenchmarkReport.ColdStart(
            attempts: observations.count,
            missingCaptions: observations.count - delays.count,
            allAttemptP95Milliseconds: p95(delays, sampleCount: observations.count),
            displayedCaptionP95Milliseconds: p95(delays, sampleCount: delays.count)
        )
    }

    private static func isValidToken(_ word: String) -> Bool {
        !word.isEmpty && word.utf8.prefix(257).count <= 256 && !word.contains(where: \.isWhitespace)
    }

    private struct Edits {
        var substitutions = 0
        var deletions = 0
        var insertions = 0

        var count: Int { substitutions + deletions + insertions }
    }

    /// Linear-space optimal token alignment with deterministic tie-breaking.
    private static func align(reference: [String], hypothesis: [String]) -> Edits {
        var prior = (0...hypothesis.count).map { Edits(insertions: $0) }
        var row = prior
        for (sourceIndex, source) in reference.enumerated() {
            row[0] = Edits(deletions: sourceIndex + 1)
            for (candidateIndex, candidate) in hypothesis.enumerated() {
                var substitution = prior[candidateIndex]
                if source != candidate { substitution.substitutions += 1 }
                var deletion = prior[candidateIndex + 1]
                deletion.deletions += 1
                var insertion = row[candidateIndex]
                insertion.insertions += 1

                var selected = substitution
                if deletion.count < selected.count { selected = deletion }
                if insertion.count < selected.count { selected = insertion }
                row[candidateIndex + 1] = selected
            }
            swap(&prior, &row)
        }
        return prior[hypothesis.count]
    }

    private static func p95(_ sorted: [Int], sampleCount: Int) -> Int? {
        guard sampleCount > 0 else { return nil }
        let rank = (95 * sampleCount + 99) / 100
        guard rank <= sorted.count else { return nil }
        return sorted[rank - 1]
    }
}
