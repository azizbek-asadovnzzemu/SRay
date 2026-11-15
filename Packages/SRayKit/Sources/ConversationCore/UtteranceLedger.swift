import Foundation

/// A period of explicitly enabled translation within one conversation.
public struct TranslationWindow: Equatable, Sendable {
    /// A fresh identity for every enable or resume action.
    public let id: UUID
    /// The monotonic session-relative instant when sending became permitted.
    public let openedAt: Duration

    /// Creates an enable window whose identity must never be reused after pause.
    public init(id: UUID, openedAt: Duration) {
        self.id = id
        self.openedAt = openedAt
    }
}

/// The reason a finalized caption cannot be submitted for ASL translation.
public enum UtteranceExclusion: Equatable, Sendable {
    /// Translation is currently disabled.
    case disabled
    /// The utterance did not begin and end inside the same enabled window.
    case crossedBoundary
    /// Source timing is absent, negative or inconsistent.
    case invalidTiming
    /// The text contains no non-whitespace characters.
    case empty
    /// The complete text exceeds 280 extended grapheme clusters.
    case tooLong
    /// The source utterance exceeds fifteen seconds.
    case tooSlow
}

/// Eligibility for submission, to be rechecked by the dispatch gate.
public enum UtteranceEligibility: Equatable, Sendable {
    /// Eligible only while the same translation window remains active.
    case eligible(windowID: UUID)
    /// Caption remains available, but ASL must be visibly omitted.
    case excluded(UtteranceExclusion)
}

/// A unique, immutable final caption with its translation eligibility.
public struct FinalizedUtterance: Equatable, Sendable {
    /// The conversation in which recognition occurred.
    public let sessionID: UUID
    /// A strictly increasing recognition sequence within that conversation.
    public let sequence: UInt64
    /// Full recognized text, never silently truncated or sentence-split.
    public let text: String
    /// Eligibility derived from the complete utterance and its original start.
    public let eligibility: UtteranceEligibility
}

/// Tracks one recognition utterance with constant-size identity bookkeeping.
///
/// The capture layer must call begin at the source utterance boundary, never
/// manufacture a start from a delayed final callback. Unknown timing is safe to
/// caption but cannot qualify for translation. A new conversation uses a new
/// ledger/session identity; recognition restarts must keep increasing sequence IDs.
public struct UtteranceLedger: Sendable {
    /// The conversation identity used in every final caption.
    private let sessionID: UUID
    /// Highest sequence ever accepted, retained after interruption for deduplication.
    private var highestSequence: UInt64?
    /// The one unfinished source utterance.
    private var pending: Pending?

    /// Start metadata retained independently of later transcription corrections.
    private struct Pending: Sendable {
        /// Recognition sequence scoped to the conversation.
        let sequence: UInt64
        /// Original speech start, if known from the source.
        let startedAt: Duration?
        /// The enable window captured at the original start.
        let window: TranslationWindow?
    }

    /// Creates an empty ledger for one conversation.
    public init(sessionID: UUID) {
        self.sessionID = sessionID
    }

    /// Registers a new source utterance without replacing unfinished work.
    /// - Returns: False for duplicates, stale sequences or an already active utterance.
    @discardableResult
    public mutating func begin(sequence: UInt64, startedAt: Duration?, window: TranslationWindow?) -> Bool {
        guard pending == nil, highestSequence.map({ sequence > $0 }) ?? true else { return false }
        highestSequence = sequence
        pending = Pending(sequence: sequence, startedAt: startedAt, window: window)
        return true
    }

    /// Returns whether a partial belongs to the active utterance; partials never create submission results.
    public func acceptsPartial(sequence: UInt64) -> Bool {
        pending?.sequence == sequence
    }

    /// Finalizes the active utterance exactly once, preserving the complete caption.
    /// - Parameters:
    ///   - endedAt: Last source speech instant, not callback arrival or processing time.
    ///   - window: The currently enabled window, or nil while paused/off.
    /// - Returns: Nil for stale or duplicate finals. An excluded result still contains its full caption.
    public mutating func finalize(sequence: UInt64, text: String, endedAt: Duration?, window: TranslationWindow?) -> FinalizedUtterance? {
        guard let source = pending, source.sequence == sequence else { return nil }
        pending = nil
        let eligibility = eligibility(for: source, text: text, endedAt: endedAt, window: window)
        return FinalizedUtterance(sessionID: sessionID, sequence: sequence, text: text, eligibility: eligibility)
    }

    /// Discards interrupted source metadata without permitting the sequence to be reused.
    /// - Returns: The interrupted sequence so the caption store can mark it explicitly.
    public mutating func interrupt() -> UInt64? {
        let sequence = pending?.sequence
        pending = nil
        return sequence
    }

    /// Applies conservative whole-utterance privacy and quality bounds.
    private func eligibility(for source: Pending, text: String, endedAt: Duration?, window: TranslationWindow?) -> UtteranceEligibility {
        guard let window else { return .excluded(.disabled) }
        guard source.window == window else { return .excluded(.crossedBoundary) }
        guard let start = source.startedAt, let end = endedAt,
              start >= .zero, window.openedAt >= .zero, end >= start else { return .excluded(.invalidTiming) }
        guard start >= window.openedAt else { return .excluded(.crossedBoundary) }
        guard text.contains(where: { !$0.isWhitespace }) else { return .excluded(.empty) }
        guard text.prefix(281).count <= 280 else { return .excluded(.tooLong) }
        guard end - start <= .seconds(15) else { return .excluded(.tooSlow) }
        return .eligible(windowID: window.id)
    }
}
