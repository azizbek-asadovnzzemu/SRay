import Foundation

/// Bounded, in-memory caption storage with no persistence or export facility.
public struct CaptionMemory: Sendable {
    /// Maximum number of partial/final rows held by one conversation.
    public static let maximumLines = 200
    /// Lifetime measured from a row's original start, never extended by corrections.
    public static let maximumAge: Duration = .seconds(600)
    /// Maximum UTF-8 bytes per row; oversized input is rejected, never truncated.
    public static let maximumBytesPerLine = 65_536
    /// Retained rows in source order.
    private var rows: [CaptionLine] = []
    /// Last observed monotonic clock value.
    private var latestInstant: Duration = .zero

    /// Creates empty session memory.
    public init() {}

    /// Updates a stable row while retaining its original timestamp.
    @discardableResult
    public mutating func update(id: UUID, text: String, isFinal: Bool, startedAt: Duration, now: Duration) -> CaptionWriteResult {
        guard now >= latestInstant, startedAt >= .zero, startedAt <= now else { return .ignored }
        prune(at: now)
        guard now - startedAt < Self.maximumAge else { return .ignored }
        guard text.utf8.prefix(Self.maximumBytesPerLine + 1).count <= Self.maximumBytesPerLine else {
            return .rejectedOversize
        }
        let row = CaptionLine(id: id, text: text, isFinal: isFinal, startedAt: startedAt)
        if let index = rows.firstIndex(where: { $0.id == id }) {
            guard !rows[index].isFinal, rows[index].startedAt == startedAt else { return .ignored }
            rows[index] = row
        } else {
            rows.append(row)
            if rows.count > Self.maximumLines { rows.removeFirst(rows.count - Self.maximumLines) }
        }
        return .stored
    }

    /// Returns currently retained rows after pruning expired content.
    public mutating func snapshot(at instant: Duration) -> [CaptionLine] {
        prune(at: instant)
        return rows
    }

    /// Drops expired rows using a nondecreasing monotonic clock.
    private mutating func prune(at instant: Duration) {
        latestInstant = max(latestInstant, instant)
        rows.removeAll { latestInstant - $0.startedAt >= Self.maximumAge }
    }

    /// Clears all retained text and timing state at conversation end.
    public mutating func clear() {
        rows.removeAll(keepingCapacity: false)
        latestInstant = .zero
    }
}
