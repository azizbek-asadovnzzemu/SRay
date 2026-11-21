import Foundation
import Observation
import SpeechCore

/// Events accepted by the caption store for the current conversation.
package enum CaptionConversationEvent {
    case opened(ContinuousClock.Instant)
    case finalized(id: UUID, String, source: SpeechSourceTiming?, receivedAt: ContinuousClock.Instant)
    case retainedCaptions(Set<UUID>)
    case closed(interrupted: Bool)
}

/// A request already started by the injected transport.
package struct ConversationTranslationRequest<Clip: Sendable> {
    package let result: @MainActor () async throws -> Clip
    package let cancel: @MainActor () -> Void

    package init(result: @escaping @MainActor () async throws -> Clip, cancel: @escaping @MainActor () -> Void) {
        self.result = result
        self.cancel = cancel
    }
}

/// A supported caption that exceeds a whole-utterance translation limit.
package enum CaptionTranslationLimit: Equatable, Sendable {
    case textLength
    case speechDuration
}

package struct ConversationTranslationPresentation<Clip: Sendable> {
    package let state: TranslationGateState
    package let ready: PreparedTranslation<Clip>?
    package let playing: ActiveTranslation<Clip>?
    package let playbackStartedAt: ContinuousClock.Instant?
    package let canReplay: Bool
    package let serviceFailed: Bool
    /// Whether the provider's cooldown currently prevents a user-initiated enable.
    package let isWaitingForRetry: Bool
    package let omissions: [UUID: TranslationOmission.Reason]
    package let captionLimits: [UUID: CaptionTranslationLimit]
}

/// Connects caption lifecycle events and explicit controls to a conversation-scoped pipeline.
@MainActor @Observable
package final class ConversationTranslation<Clip: Sendable> {
    package private(set) var presentation = ConversationTranslationPresentation<Clip>(
        state: .idle, ready: nil, playing: nil, playbackStartedAt: nil, canReplay: false, serviceFailed: false,
        isWaitingForRetry: false, omissions: [:], captionLimits: [:]
    )
    /// Aggregates the outcomes of the active conversation in memory.
    @ObservationIgnored package private(set) var evaluation = TranslationEvaluationSummary()

    @ObservationIgnored private let now: @MainActor () -> ContinuousClock.Instant
    @ObservationIgnored private let startRequest: @MainActor (String) throws -> ConversationTranslationRequest<Clip>
    @ObservationIgnored private var origin: ContinuousClock.Instant?
    @ObservationIgnored private var ledger: UtteranceLedger?
    @ObservationIgnored private var sequence: UInt64 = 0
    @ObservationIgnored private var serviceFailed = false
    @ObservationIgnored private var retryCooldown: RetryCooldown?
    @ObservationIgnored private var awaitingCaptions: [UInt64: AwaitingCaption] = [:]
    @ObservationIgnored private var omissions: [UUID: TranslationOmission.Reason] = [:]
    @ObservationIgnored private var captionLimits: [UUID: CaptionTranslationLimit] = [:]
    @ObservationIgnored private var expiryTask: Task<Void, Never>?
    @ObservationIgnored private var pending: PendingRequest?
    @ObservationIgnored private lazy var pipeline = TranslationPipeline<Clip>(
        startSubmission: { [weak self] text, token in self?.submit(text, token: token) },
        cancelSubmission: { [weak self] token in self?.cancel(token) }
    )

    private struct RetryCooldown {
        let receivedAt: ContinuousClock.Instant
        let delay: Duration
    }

    private struct AwaitingCaption {
        let id: UUID?
        let finalizedAt: Duration
    }

    private struct PlaybackClock {
        let id: UUID
        let startedAt: ContinuousClock.Instant
    }

    @ObservationIgnored private var playbackClock: PlaybackClock?

    private struct PendingRequest {
        let token: SubmissionToken
        let operation: ConversationTranslationRequest<Clip>
        let observer: Task<Void, Never>
    }

    package init(
        now: @escaping @MainActor () -> ContinuousClock.Instant = { .now },
        startRequest: @escaping @MainActor (String) throws -> ConversationTranslationRequest<Clip>
    ) {
        self.now = now
        self.startRequest = startRequest
    }

    /// Applies a caption event from the one app-owned session.
    package func receive(_ event: CaptionConversationEvent) {
        switch event {
        case .opened(let instant):
            guard let id = pipeline.startConversation() else { return }
            origin = instant
            ledger = UtteranceLedger(sessionID: id)
            sequence = 0
            serviceFailed = false
        case .finalized(let id, let text, let source, let receivedAt):
            acceptFinal(id: id, text: text, source: source, receivedAt: receivedAt)
        case .retainedCaptions(let ids):
            awaitingCaptions = awaitingCaptions.mapValues { caption in
                guard let id = caption.id, !ids.contains(id) else { return caption }
                return AwaitingCaption(id: nil, finalizedAt: caption.finalizedAt)
            }
            omissions = omissions.filter { ids.contains($0.key) }
            captionLimits = captionLimits.filter { ids.contains($0.key) }
        case .closed(let interrupted):
            origin = nil
            ledger = nil
            serviceFailed = false
            awaitingCaptions.removeAll()
            evaluation = TranslationEvaluationSummary()
            omissions.removeAll()
            captionLimits.removeAll()
            if interrupted { pipeline.interrupt() } else { pipeline.endConversation() }
        }
        publish()
    }

    package func enable() {
        let instant = now()
        guard let origin, remainingRetryDelay(at: instant) == nil,
              pipeline.enableASL(at: origin.duration(to: instant)) else { return }
        serviceFailed = false
        publish()
    }

    package func pause() {
        record(pipeline.pauseASL())
        publish()
    }

    package func beginPlayback(for token: SubmissionToken) {
        guard let elapsed else { return }
        let attempt = pipeline.beginPlayback(for: token, at: elapsed)
        record(attempt.omissions)
        if attempt.started, let caption = awaitingCaptions.removeValue(forKey: token.sequence) {
            evaluation.recordHandoff(after: elapsed - caption.finalizedAt)
        }
        publish()
    }

    /// Starts the shared clock when the first view mounts for the current attempt.
    package func attachPlaybackView(id: UUID) {
        guard pipeline.activePlayback?.id == id, playbackClock?.id != id else { return }
        playbackClock = PlaybackClock(id: id, startedAt: now())
        publish()
    }

    package func finishPlayback(id: UUID) {
        guard let elapsed else { return }
        record(pipeline.finishPlayback(for: id, at: elapsed))
        publish()
    }

    package func replay() {
        guard let elapsed else { return }
        _ = pipeline.beginReplay(at: elapsed)
        publish()
    }

    private var elapsed: Duration? { origin.map { $0.duration(to: now()) } }

    private func acceptFinal(
        id: UUID, text: String, source: SpeechSourceTiming?, receivedAt: ContinuousClock.Instant
    ) {
        guard let origin, let source, let window = pipeline.currentWindow,
              source.startedAt >= origin, source.endedAt <= receivedAt,
              sequence < UInt64.max else { return }
        let start = origin.duration(to: source.startedAt)
        guard start > window.openedAt else { return }
        let end = origin.duration(to: source.endedAt)
        let finalizedAt = origin.duration(to: receivedAt)
        sequence += 1
        guard ledger?.begin(sequence: sequence, startedAt: start, window: window) == true,
              let final = ledger?.finalize(sequence: sequence, text: text, endedAt: end, window: window) else { return }
        switch final.eligibility {
        case .eligible:
            awaitingCaptions[final.sequence] = AwaitingCaption(id: id, finalizedAt: finalizedAt)
            record(pipeline.enqueue(final, finalizedAt: finalizedAt, at: finalizedAt))
        case .excluded(.tooLong):
            captionLimits[id] = .textLength
        case .excluded(.tooSlow):
            captionLimits[id] = .speechDuration
        case .excluded:
            break
        }
    }

    private func submit(_ text: String, token: SubmissionToken) {
        do {
            let operation = try startRequest(text)
            guard pipeline.currentWindow?.id == token.windowID else {
                operation.cancel()
                return
            }
            let observer = Task { [weak self] in
                do {
                    let clip = try await operation.result()
                    self?.complete(token: token, result: .success(clip))
                } catch {
                    self?.complete(token: token, result: .failure(error))
                }
            }
            pending = PendingRequest(token: token, operation: operation, observer: observer)
        } catch {
            fail(error, for: token)
        }
    }

    private func cancel(_ token: SubmissionToken) {
        guard let request = pending, request.token == token else { return }
        pending = nil
        request.operation.cancel()
        request.observer.cancel()
    }

    private func complete(token: SubmissionToken, result: Result<Clip, any Error>) {
        guard pending?.token == token, let elapsed else { return }
        pending = nil
        switch result {
        case .success(let clip):
            record(pipeline.receive(clip, for: token, at: elapsed))
        case .failure(let error):
            fail(error, for: token)
        }
        publish()
    }

    private func fail(_ error: any Error, for token: SubmissionToken) {
        guard let origin else { return }
        let instant = now()
        let retryDelay = (error as? any TranslationRetryAdvising)?.retryDelay(relativeTo: .now) ?? .zero
        record(pipeline.requestFailed(
            for: token, at: origin.duration(to: instant), pauseAfterExpiry: retryDelay > .zero
        ))
        serviceFailed = pipeline.state == .paused
        if serviceFailed, retryDelay > .zero {
            retryCooldown = RetryCooldown(receivedAt: instant, delay: retryDelay)
        }
    }

    private func remainingRetryDelay(at time: ContinuousClock.Instant) -> Duration? {
        guard let retryCooldown else { return nil }
        let elapsed = max(.zero, retryCooldown.receivedAt.duration(to: time))
        return elapsed < retryCooldown.delay ? retryCooldown.delay - elapsed : nil
    }

    private func record(_ outcomes: [TranslationOmission]) {
        for outcome in outcomes {
            evaluation.recordOmission(outcome.reason)
            guard let id = awaitingCaptions.removeValue(forKey: outcome.sequence)?.id else { continue }
            omissions[id] = outcome.reason
        }
    }

    private func publish() {
        let playing = pipeline.activePlayback
        if playbackClock?.id != playing?.id { playbackClock = nil }
        let instant = now()
        let retryDelay = remainingRetryDelay(at: instant)
        if retryDelay == nil { retryCooldown = nil }
        presentation = ConversationTranslationPresentation(
            state: pipeline.state, ready: pipeline.readyForPlayback, playing: playing,
            playbackStartedAt: playbackClock?.startedAt,
            canReplay: pipeline.canReplay, serviceFailed: serviceFailed, isWaitingForRetry: retryDelay != nil,
            omissions: omissions, captionLimits: captionLimits
        )

        expiryTask?.cancel()
        expiryTask = nil
        guard let origin else { return }
        let queueDeadline = pipeline.nextExpiry.map { origin.advanced(by: $0) }
        // Large server delays use bounded wakeups rather than one unbounded clock sleep.
        let retryWake = retryDelay.map { instant.advanced(by: min($0, .seconds(3_600))) }
        guard let deadline = [queueDeadline, retryWake].compactMap({ $0 }).min() else { return }
        expiryTask = Task { [weak self] in
            do {
                try await ContinuousClock().sleep(until: deadline)
            } catch {
                return
            }
            guard let self, !Task.isCancelled, self.origin == origin, let elapsed = self.elapsed else { return }
            self.record(self.pipeline.advance(to: elapsed))
            self.publish()
        }
    }

    /// Allows package tests to await the current response without sleeping.
    func waitForRequest() async {
        await pending?.observer.value
    }
}
