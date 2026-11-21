import Foundation

/// An ASL omission associated with a caption sequence in the current conversation.
public struct TranslationOmission: Equatable, Sendable {
    /// Why no signed output will be shown for the caption.
    public enum Reason: Hashable, Sendable {
        case capacity, expired, requestFailed, cancelled
    }

    /// Original caption sequence.
    public let sequence: UInt64
    /// Reason to show alongside the retained caption.
    public let reason: Reason
}

/// Outcome of attempting to queue an eligible final caption.
public enum TranslationAdmission: Equatable, Sendable {
    case queued
    case omitted(TranslationOmission)
    case ignored
}

/// The next signed result, still counted against waiting capacity until its first frame.
public struct ReadyTranslation<Clip: Sendable>: Sendable {
    /// Original caption sequence in the queue's conversation.
    public let sequence: UInt64
    /// The validated clip supplied by the decoder.
    public let clip: Clip
}

/// FIFO admission and first-frame accounting for a single enable window.
///
/// Call `advance(to:)` before processing each external event and when
/// `nextExpiry` is reached. The coordinator applies returned omissions
/// and cancels the corresponding transport or pre-render work. Use a new
/// instance on resume. The queue has no timers, networking, or decoder.
public struct TranslationQueue<Clip: Sendable>: Sendable {
    /// Maximum count awaiting a first signed frame, including request and ready stages.
    public static var waitingLimit: Int { 2 }
    /// Time from finalization to the first visible signed frame.
    public static var waitLimit: Duration { .seconds(10) }

    /// The conversation associated with every caption in this queue.
    public let sessionID: UUID
    /// The translation window authorized to create new work.
    public let windowID: UUID
    /// Caption currently playing, outside the waiting capacity.
    public private(set) var playingSequence: UInt64?
    /// Count of queued, in-flight and ready work.
    public var waitingCount: Int { queued.count + (current == nil ? 0 : 1) }
    /// Earliest outstanding deadline for the caller's monotonic timer.
    public var nextExpiry: Duration? {
        let deadlines = queued.map(\.deadline) + [current?.deadline].compactMap { $0 }
        return deadlines.min()
    }
    /// A clip may prepare for display only when the previous clip has finished.
    public var readyForPlayback: ReadyTranslation<Clip>? {
        guard playingSequence == nil, case .ready(let ready, _) = current else { return nil }
        return ready
    }

    private struct Waiting: Sendable {
        let utterance: FinalizedUtterance
        let deadline: Duration
    }

    private enum Current: Sendable {
        case request(sequence: UInt64, deadline: Duration)
        case ready(ReadyTranslation<Clip>, deadline: Duration)

        var deadline: Duration {
            switch self {
            case .request(_, let deadline), .ready(_, let deadline): deadline
            }
        }

        var sequence: UInt64 {
            switch self {
            case .request(let sequence, _): sequence
            case .ready(let ready, _): ready.sequence
            }
        }
    }

    private var queued: [Waiting] = []
    private var current: Current?
    private var lastSequence: UInt64?
    private var instant: Duration = .zero
    private var closed = false

    /// Creates an empty queue for explicitly enabled translation.
    public init(sessionID: UUID, windowID: UUID) {
        self.sessionID = sessionID
        self.windowID = windowID
    }

    /// Expires all work that missed its first-frame deadline. Active playback continues.
    public mutating func advance(to time: Duration) -> [TranslationOmission] {
        guard time >= instant else { return [] }
        instant = time
        var expired: [TranslationOmission] = []
        if let entry = current, entry.deadline <= time {
            expired.append(.init(sequence: entry.sequence, reason: .expired))
            current = nil
        }
        queued.removeAll { entry in
            guard entry.deadline <= time else { return false }
            expired.append(.init(sequence: entry.utterance.sequence, reason: .expired))
            return true
        }
        return expired
    }

    /// Admits an eligible caption, or reports an omission without evicting earlier work.
    public mutating func enqueue(_ utterance: FinalizedUtterance, finalizedAt: Duration) -> TranslationAdmission {
        guard !closed, utterance.sessionID == sessionID,
              utterance.eligibility == .eligible(windowID: windowID),
              lastSequence.map({ utterance.sequence > $0 }) ?? true,
              finalizedAt >= .zero, finalizedAt <= instant,
              finalizedAt.components.seconds < Int64.max - 10 else { return .ignored }
        lastSequence = utterance.sequence
        let deadline = finalizedAt + Self.waitLimit
        guard deadline > instant else {
            return .omitted(.init(sequence: utterance.sequence, reason: .expired))
        }
        guard waitingCount < Self.waitingLimit else {
            return .omitted(.init(sequence: utterance.sequence, reason: .capacity))
        }
        queued.append(.init(utterance: utterance, deadline: deadline))
        return .queued
    }

    /// Claims the next request in order, releasing the queue's copy of its text.
    public mutating func takeNextRequest() -> FinalizedUtterance? {
        guard current == nil, !queued.isEmpty else { return nil }
        let entry = queued.removeFirst()
        current = .request(sequence: entry.utterance.sequence, deadline: entry.deadline)
        return entry.utterance
    }

    /// Stores a validated response only if the matching request is still current.
    @discardableResult
    public mutating func accept(_ clip: Clip, for sequence: UInt64) -> Bool {
        guard case .request(let pending, let deadline) = current, pending == sequence else { return false }
        current = .ready(.init(sequence: sequence, clip: clip), deadline: deadline)
        return true
    }

    /// Records a matching request failure and releases its waiting slot.
    public mutating func failRequest(for sequence: UInt64) -> TranslationOmission? {
        guard case .request(let pending, _) = current, pending == sequence else { return nil }
        current = nil
        return .init(sequence: sequence, reason: .requestFailed)
    }

    /// Releases the ready slot at the first displayed frame, never before.
    @discardableResult
    public mutating func markFirstFrame(for sequence: UInt64) -> Bool {
        guard playingSequence == nil, case .ready(let ready, _) = current,
              ready.sequence == sequence else { return false }
        current = nil
        playingSequence = sequence
        return true
    }

    /// Clears active playback after its last frame or a playback failure.
    public mutating func finishPlayback(for sequence: UInt64) {
        guard playingSequence == sequence else { return }
        playingSequence = nil
    }

    /// Permanently closes this enable window and reports all outstanding omissions.
    /// The coordinator stops any active renderer and cancels the transport before acknowledging pause.
    public mutating func close() -> [TranslationOmission] {
        closed = true
        var omissions = queued.map { TranslationOmission(sequence: $0.utterance.sequence, reason: .cancelled) }
        if let current {
            omissions.insert(.init(sequence: current.sequence, reason: .cancelled), at: 0)
        }
        current = nil
        queued.removeAll()
        playingSequence = nil
        return omissions
    }
}
