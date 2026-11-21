import Foundation

/// A validated clip with the identity the renderer must present at its first frame.
public struct PreparedTranslation<Clip: Sendable>: Sendable {
    /// Identifies the conversation, enable window and caption sequence.
    public let token: SubmissionToken
    /// The validated clip awaiting its first shown frame.
    public let clip: Clip
}

/// Coordinates a single conversation's dispatch gate and first-frame queue.
///
/// Callers use one monotonic conversation clock and schedule `advance(to:)`
/// at `nextExpiry`. The transport starts synchronously at the gate and returns
/// validated clips or failures as separate events. The renderer owns active
/// and replay clips and observes playback identity before displaying frames.
@MainActor
public final class TranslationPipeline<Clip: Sendable> {
    /// Current transmission permission across all conversation windows.
    public var state: TranslationGateState { gate.state }
    /// The window to snapshot with an utterance's source start.
    public var currentWindow: TranslationWindow? { gate.currentWindow }
    /// Number of eligible utterances awaiting their first shown frame.
    public var waitingCount: Int { queue?.waitingCount ?? 0 }
    /// Next deadline in session-relative monotonic time, including ready poses.
    public var nextExpiry: Duration? { queue?.nextExpiry }
    /// Validated pose eligible to start display as soon as the renderer is ready.
    public var readyForPlayback: PreparedTranslation<Clip>? {
        guard let queue, let ready = queue.readyForPlayback else { return nil }
        return PreparedTranslation(token: playbackToken(for: ready.sequence, in: queue), clip: ready.clip)
    }
    /// Active display identity. It becomes nil when the renderer must stop.
    public var playing: SubmissionToken? {
        guard let queue, let sequence = queue.playingSequence else { return nil }
        return playbackToken(for: sequence, in: queue)
    }

    private let gate: TranslationGate
    private let startSubmission: @MainActor (_ text: String, _ token: SubmissionToken) -> Void
    private var queue: TranslationQueue<Clip>?
    private var instant: Duration = .zero

    /// Creates a closed pipeline with a synchronous, cancellable transport dependency.
    public init(
        startSubmission: @escaping @MainActor (_ text: String, _ token: SubmissionToken) -> Void,
        cancelSubmission: @escaping @MainActor (_ token: SubmissionToken) -> Void
    ) {
        gate = TranslationGate(cancelSubmission: cancelSubmission)
        self.startSubmission = startSubmission
    }

    /// Starts a new captions-only conversation, or returns nil if one already exists.
    public func startConversation() -> UUID? {
        guard let id = gate.startConversation() else { return nil }
        instant = .zero
        return id
    }

    /// Opens a new window for speech that begins at or after the enable instant.
    @discardableResult
    public func enableASL(at time: Duration) -> Bool {
        guard let sessionID = gate.sessionID, time >= instant,
              gate.enableASL(at: time), let window = gate.currentWindow else { return false }
        instant = time
        queue = TranslationQueue(sessionID: sessionID, windowID: window.id)
        return true
    }

    /// Discards the window's pending work and invalidates callbacks before cancellation.
    public func pauseASL() -> [TranslationOmission] {
        guard state == .enabled else { return [] }
        let omissions = queue?.close() ?? []
        queue = nil
        gate.pauseASL()
        return omissions
    }

    /// Releases conversation-scoped work and returns to idle.
    public func endConversation() {
        queue = nil
        gate.endConversation()
    }

    /// Ends the conversation so ASL requires a fresh conversation and explicit enable.
    public func interrupt() {
        queue = nil
        gate.interrupt()
    }

    /// Queues a unique eligible final and starts its request when a slot is available.
    /// A full queue preserves earlier work and reports the new arrival as omitted.
    public func enqueue(
        _ utterance: FinalizedUtterance, finalizedAt: Duration, at time: Duration
    ) -> [TranslationOmission] {
        guard utterance.sessionID == gate.sessionID, let window = gate.currentWindow,
              utterance.eligibility == .eligible(windowID: window.id),
              var omissions = expire(to: time) else { return [] }
        if case .omitted(let omission)? = queue?.enqueue(utterance, finalizedAt: finalizedAt) {
            omissions.append(omission)
        }
        dispatchNext()
        return omissions
    }

    /// Records a validated clip only for the current, unexpired request.
    public func receive(_ clip: Clip, for token: SubmissionToken, at time: Duration) -> [TranslationOmission] {
        guard gate.activeSubmission == token, let omissions = expire(to: time) else { return [] }
        if gate.complete(token) {
            queue?.accept(clip, for: token.sequence)
        }
        dispatchNext()
        return omissions
    }

    /// Stops submission after a current request fails. Recovery requires explicit enable.
    public func requestFailed(for token: SubmissionToken, at time: Duration) -> [TranslationOmission] {
        guard gate.activeSubmission == token, var omissions = expire(to: time) else { return [] }
        if gate.complete(token) {
            if let failed = queue?.failRequest(for: token.sequence) { omissions.append(failed) }
            omissions += pauseASL()
        } else {
            dispatchNext()
        }
        return omissions
    }

    /// Commits the renderer's first displayed frame and releases the ready slot.
    /// Commit display only if the returned `started` value is true.
    public func beginPlayback(
        for token: SubmissionToken, at time: Duration
    ) -> (started: Bool, omissions: [TranslationOmission]) {
        guard readyForPlayback?.token == token, let omissions = expire(to: time) else { return (false, []) }
        if readyForPlayback?.token == token {
            queue?.markFirstFrame(for: token.sequence)
        }
        dispatchNext()
        return (playing == token, omissions)
    }

    /// Releases active playback if the completion still belongs to it.
    public func finishPlayback(for token: SubmissionToken, at time: Duration) -> [TranslationOmission] {
        guard playing == token, let omissions = expire(to: time) else { return [] }
        if playing == token { queue?.finishPlayback(for: token.sequence) }
        dispatchNext()
        return omissions
    }

    /// Expires waiting work at its deadline and starts the next eligible request.
    public func advance(to time: Duration) -> [TranslationOmission] {
        guard let omissions = expire(to: time) else { return [] }
        dispatchNext()
        return omissions
    }

    private func expire(to time: Duration) -> [TranslationOmission]? {
        guard time >= instant else { return nil }
        instant = time
        let omissions = queue?.advance(to: time) ?? []
        if let token = gate.activeSubmission, omissions.contains(where: { $0.sequence == token.sequence }) {
            gate.cancel(token)
        }
        return omissions
    }

    private func dispatchNext() {
        guard gate.activeSubmission == nil, let utterance = queue?.takeNextRequest() else { return }
        gate.dispatch(utterance) { token in
            startSubmission(utterance.text, token)
        }
    }

    private func playbackToken(for sequence: UInt64, in queue: TranslationQueue<Clip>) -> SubmissionToken {
        SubmissionToken(sessionID: queue.sessionID, windowID: queue.windowID, sequence: sequence)
    }
}
