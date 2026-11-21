import Foundation

/// Explicit conversation and transmission states shared by all windows.
public enum TranslationGateState: Equatable, Sendable {
    /// No conversation is running.
    case idle
    /// Captions are active; ASL has not been enabled.
    case captionsOnly
    /// Future wholly eligible utterances may be submitted automatically.
    case enabled
    /// Captions continue, but text submission is closed.
    case paused
    /// An interruption ended capture/transmission and requires a new explicit start.
    case interrupted
}

/// Identifies one submitted request without retaining its text.
public struct SubmissionToken: Equatable, Sendable {
    /// The conversation that owned the request.
    public let sessionID: UUID
    /// The enable/resume window that authorized it.
    public let windowID: UUID
    /// The finalized source utterance sequence.
    public let sequence: UInt64
}

/// Serializes dispatch with enable, pause, completion and conversation termination.
///
/// Share one gate at the app composition root. Submission starts synchronously
/// on the main actor so no await can separate eligibility validation from request
/// creation. Already-dispatched text cannot be retracted; cancellation is best effort.
@MainActor
public final class TranslationGate {
    /// The visible transmission state.
    public private(set) var state: TranslationGateState = .idle
    /// The current conversation, absent after end or interruption.
    public private(set) var sessionID: UUID?
    /// The window to snapshot at a source utterance's actual beginning.
    public private(set) var currentWindow: TranslationWindow?
    /// The single submitted request; queueing belongs to the pipeline coordinator.
    private(set) var activeSubmission: SubmissionToken?
    /// A bounded watermark preventing duplicate or out-of-order submissions.
    private var lastSubmittedSequence: UInt64?
    /// The transport cancellation hook, invoked only after eligibility is invalidated.
    private let cancelSubmission: @MainActor (SubmissionToken) -> Void

    /// Creates a closed gate with an explicit transport cancellation dependency.
    public init(cancelSubmission: @escaping @MainActor (SubmissionToken) -> Void) {
        self.cancelSubmission = cancelSubmission
    }

    /// Starts a new captions-only conversation, refusing a second window's duplicate start.
    /// - Returns: The new identity, or nil while a conversation is already active.
    @discardableResult
    public func startConversation() -> UUID? {
        guard sessionID == nil else { return nil }
        let id = UUID()
        sessionID = id
        lastSubmittedSequence = nil
        currentWindow = nil
        state = .captionsOnly
        return id
    }

    /// Explicitly enables or resumes ASL for future speech in a fresh window.
    /// - Parameter instant: Nonnegative monotonic time relative to this conversation's start.
    /// - Returns: False outside an active paused/captions-only conversation.
    @discardableResult
    public func enableASL(at instant: Duration) -> Bool {
        guard sessionID != nil, instant >= .zero,
              state == .captionsOnly || state == .paused else { return false }
        currentWindow = TranslationWindow(id: UUID(), openedAt: instant)
        state = .enabled
        return true
    }

    /// Closes submission before requesting cancellation; captions remain active.
    public func pauseASL() {
        guard sessionID != nil else { return }
        invalidate(nextState: .paused, endsConversation: false)
    }

    /// Ends the conversation and invalidates all callbacks before cancellation.
    public func endConversation() {
        invalidate(nextState: .idle, endsConversation: true)
    }

    /// Ends transmission on interruption without allowing a resume to revive the session.
    public func interrupt() {
        invalidate(nextState: .interrupted, endsConversation: true)
    }

    /// Starts one eligible request atomically with gate validation.
    ///
    /// The closure must synchronously create/start the cancellable request. It
    /// must not defer the actual dispatch into another task or across an await.
    /// Rejection never queues text for later replay or changes caption processing.
    /// - Returns: Whether a request was accepted for dispatch.
    @discardableResult
    public func dispatch(_ utterance: FinalizedUtterance, start: @MainActor (SubmissionToken) -> Void) -> Bool {
        guard state == .enabled, let sessionID, let window = currentWindow,
              utterance.sessionID == sessionID,
              utterance.eligibility == .eligible(windowID: window.id),
              activeSubmission == nil,
              lastSubmittedSequence.map({ utterance.sequence > $0 }) ?? true else { return false }
        let token = SubmissionToken(sessionID: sessionID, windowID: window.id, sequence: utterance.sequence)
        lastSubmittedSequence = utterance.sequence
        activeSubmission = token
        start(token)
        return true
    }

    /// Accepts a completion exactly once only while its original window is still enabled.
    /// - Returns: False for stale, cancelled, duplicate or foreign completions.
    @discardableResult
    public func complete(_ token: SubmissionToken) -> Bool {
        guard state == .enabled, activeSubmission == token,
              sessionID == token.sessionID, currentWindow?.id == token.windowID else { return false }
        activeSubmission = nil
        return true
    }

    /// Releases and cancels the matching expired submission, leaving the window enabled.
    func cancel(_ token: SubmissionToken) {
        guard complete(token) else { return }
        cancelSubmission(token)
    }

    /// Invalidates state synchronously before calling externally supplied cancellation code.
    private func invalidate(nextState: TranslationGateState, endsConversation: Bool) {
        let cancelled = activeSubmission
        activeSubmission = nil
        currentWindow = nil
        state = nextState
        if endsConversation { sessionID = nil }
        if let cancelled { cancelSubmission(cancelled) }
    }
}
