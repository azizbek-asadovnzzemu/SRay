import Foundation

/// A stable, session-only caption row that evolves from partial to final text.
public struct CaptionLine: Identifiable, Equatable, Sendable {
    /// Identity allocated once for a recognition request, never derived from text.
    public let id: UUID
    /// Complete caption text within the bounded input envelope.
    public let text: String
    /// Whether the recognizer finalized this row.
    public let isFinal: Bool
    /// Monotonic session-relative time when this row first began.
    public let startedAt: Duration
}

/// Outcome of a caption-memory update without retaining rejected text.
public enum CaptionWriteResult: Equatable, Sendable {
    /// The partial or final row was stored.
    case stored
    /// Stale, expired, invalid or already-final work was ignored.
    case ignored
    /// The entire oversized input was rejected; the UI must report the omission.
    case rejectedOversize
}
