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

package struct ConversationTranslationPresentation<Clip: Sendable> {
    package let state: TranslationGateState
    package let ready: PreparedTranslation<Clip>?
    package let playing: ActiveTranslation<Clip>?
    package let canReplay: Bool
    package let serviceFailed: Bool
    package let omissions: [UUID: TranslationOmission.Reason]
}

/// Connects caption lifecycle events and explicit controls to a conversation-scoped pipeline.
@MainActor @Observable
package final class ConversationTranslation<Clip: Sendable> {
    package private(set) var presentation = ConversationTranslationPresentation<Clip>(
        state: .idle, ready: nil, playing: nil, canReplay: false, serviceFailed: false, omissions: [:]
    )
    /// Aggregates the outcomes of the active conversation in memory.
    @ObservationIgnored package private(set) var evaluation = TranslationEvaluationSummary()

    @ObservationIgnored private let now: @MainActor () -> ContinuousClock.Instant
    @ObservationIgnored private let startRequest: @MainActor (String) throws -> ConversationTranslationRequest<Clip>
    @ObservationIgnored private var origin: ContinuousClock.Instant?
    @ObservationIgnored private var ledger: UtteranceLedger?
    @ObservationIgnored private var sequence: UInt64 = 0
    @ObservationIgnored private var serviceFailed = false
    @ObservationIgnored private var awaitingCaptions: [UInt64: AwaitingCaption] = [:]
    @ObservationIgnored private var omissions: [UUID: TranslationOmission.Reason] = [:]
    @ObservationIgnored private var expiryTask: Task<Void, Never>?
    @ObservationIgnored private var pending: PendingRequest?
    @ObservationIgnored private lazy var pipeline = TranslationPipeline<Clip>(
        startSubmission: { [weak self] text, token in self?.submit(text, token: token) },
        cancelSubmission: { [weak self] token in self?.cancel(token) }
    )

    private struct AwaitingCaption {
        let id: UUID?
        let finalizedAt: Duration
    }

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
        case .closed(let interrupted):
            origin = nil
            ledger = nil
            serviceFailed = false
            awaitingCaptions.removeAll()
            evaluation = TranslationEvaluationSummary()
            omissions.removeAll()
            if interrupted { pipeline.interrupt() } else { pipeline.endConversation() }
        }
        publish()
    }

    package func enable() {
        guard let elapsed, pipeline.enableASL(at: elapsed) else { return }
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
        awaitingCaptions[final.sequence] = AwaitingCaption(id: id, finalizedAt: finalizedAt)
        record(pipeline.enqueue(final, finalizedAt: finalizedAt, at: finalizedAt))
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
                    self?.complete(token: token, clip: clip)
                } catch {
                    self?.complete(token: token, clip: nil)
                }
            }
            pending = PendingRequest(token: token, operation: operation, observer: observer)
        } catch {
            fail(token)
        }
    }

    private func cancel(_ token: SubmissionToken) {
        guard let request = pending, request.token == token else { return }
        pending = nil
        request.operation.cancel()
        request.observer.cancel()
    }

    private func complete(token: SubmissionToken, clip: Clip?) {
        guard pending?.token == token, let elapsed else { return }
        pending = nil
        if let clip {
            record(pipeline.receive(clip, for: token, at: elapsed))
        } else {
            fail(token)
        }
        publish()
    }

    private func fail(_ token: SubmissionToken) {
        guard let elapsed else { return }
        record(pipeline.requestFailed(for: token, at: elapsed))
        serviceFailed = pipeline.state == .paused
    }

    private func record(_ outcomes: [TranslationOmission]) {
        for outcome in outcomes {
            evaluation.recordOmission(outcome.reason)
            guard let id = awaitingCaptions.removeValue(forKey: outcome.sequence)?.id else { continue }
            omissions[id] = outcome.reason
        }
    }

    private func publish() {
        presentation = ConversationTranslationPresentation(
            state: pipeline.state, ready: pipeline.readyForPlayback, playing: pipeline.activePlayback,
            canReplay: pipeline.canReplay, serviceFailed: serviceFailed, omissions: omissions
        )

        expiryTask?.cancel()
        expiryTask = nil
        guard let origin, let deadline = pipeline.nextExpiry else { return }
        expiryTask = Task { [weak self] in
            do {
                try await ContinuousClock().sleep(until: origin.advanced(by: deadline))
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
