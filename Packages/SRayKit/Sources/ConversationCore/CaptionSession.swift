import Foundation
import Observation
import SpeechCore

/// Owns one captions-only conversation for all app windows.
@MainActor @Observable
public final class CaptionSession {
    /// Current display and capture state.
    public private(set) var phase: CaptionSessionPhase = .ready
    /// The bounded transcript, including its current partial when present.
    public private(set) var lines: [CaptionLine] = []
    /// Whether the current conversation can be ended explicitly.
    public var canEnd: Bool { origin != nil }

    @ObservationIgnored private let speech: SpeechSession
    @ObservationIgnored private let events: (@MainActor (CaptionConversationEvent) -> Void)?
    @ObservationIgnored private let now: @MainActor () -> ContinuousClock.Instant
    @ObservationIgnored private var memory = CaptionMemory()
    private var origin: ContinuousClock.Instant?
    @ObservationIgnored private var capture: Task<Void, Never>?
    @ObservationIgnored private var expiry: Task<Void, Never>?
    @ObservationIgnored private var requestID: UUID?
    @ObservationIgnored private var openWindows: Set<UUID> = []

    /// Creates a room for local captions around one exclusively owned microphone backend.
    public convenience init(backend: any SpeechBackend) {
        self.init(backend: backend, now: { .now })
    }

    /// Creates a session with a testable monotonic time source.
    package init(
        backend: any SpeechBackend,
        now: @escaping @MainActor () -> ContinuousClock.Instant,
        events: (@MainActor (CaptionConversationEvent) -> Void)? = nil
    ) {
        speech = SpeechSession(backend: backend)
        self.now = now
        self.events = events
    }

    /// Starts or continues captions after an explicit user action.
    public func start() {
        guard requestID == nil else { return }
        let instant = now()
        let opensConversation = origin == nil
        let origin = origin ?? instant
        self.origin = origin
        let id = UUID()
        let startedAt = origin.duration(to: instant)
        requestID = id
        phase = .preparing
        if opensConversation { events?(.opened(origin)) }
        guard requestID == id else { return }
        capture = Task { [weak self, speech] in
            await speech.run(onListening: {
                guard let self, self.requestID == id else { return }
                self.phase = .listening
            }, onEvent: { event in
                self?.receive(event, id: id, startedAt: startedAt)
            })
            self?.finishRequest(id: id)
        }
    }

    /// Stops capture immediately and releases all visible and retained caption text.
    public func end() {
        clear(nextPhase: .ready)
    }

    /// Stops capture and releases the conversation after a lifecycle interruption.
    public func interrupt() {
        guard origin != nil else { return }
        clear(nextPhase: .interrupted)
    }

    /// Registers a presented conversation window.
    public func windowDidOpen(_ id: UUID) {
        openWindows.insert(id)
    }

    /// Stops the shared conversation when its last presented window closes.
    public func windowDidClose(_ id: UUID) {
        guard openWindows.remove(id) != nil, openWindows.isEmpty else { return }
        interrupt()
    }

    /// Waits for the current recognition request to finish, if one is active.
    func waitForCaptureToFinish() async {
        await capture?.value
    }

    /// Removes expired captions even when speech has stopped.
    func expireCaptions() {
        guard let origin else { return }
        updateLines(at: origin.duration(to: now()))
    }

    private func updateLines(at elapsed: Duration) {
        let previousFirst = lines.first?.id
        lines = memory.snapshot(at: elapsed)
        scheduleExpiry()
        if let events, let previousFirst, previousFirst != lines.first?.id {
            events(.retainedCaptions(Set(lines.map(\.id))))
        }
    }

    private func receive(_ event: SpeechEvent, id: UUID, startedAt: Duration) {
        guard requestID == id, let origin else { return }
        let instant = now()
        let elapsed = origin.duration(to: instant)
        let result = memory.update(id: id, text: event.text, isFinal: event.isFinal, startedAt: startedAt, now: elapsed)
        updateLines(at: elapsed)
        if let events, requestID == id, result == .stored, event.isFinal {
            let timing = event.sourceTiming.flatMap { source in
                source.startedAt >= origin.advanced(by: startedAt) && source.startedAt <= source.endedAt
                    && source.endedAt <= instant ? source : nil
            }
            events(.finalized(id: id, event.text, source: timing, receivedAt: instant))
        }
        if result == .rejectedOversize {
            stopCapture()
            phase = .oversized
        }
    }

    private func finishRequest(id: UUID) {
        guard requestID == id else { return }
        requestID = nil
        capture = nil
        switch speech.state {
        case .failed(.interrupted):
            interrupt()
        case .failed(let reason):
            phase = .failed(reason)
        default:
            phase = .finished
        }
    }

    private func scheduleExpiry() {
        expiry?.cancel()
        expiry = nil
        guard let origin, let row = lines.first else { return }
        let deadline = origin.advanced(by: row.startedAt + CaptionMemory.maximumAge)
        expiry = Task { [weak self] in
            do {
                try await ContinuousClock().sleep(until: deadline)
                guard !Task.isCancelled else { return }
                self?.expireCaptions()
            } catch {
                // A newer snapshot or an ended conversation cancelled this timer.
            }
        }
    }

    private func stopCapture() {
        requestID = nil
        speech.stop()
        capture?.cancel()
        capture = nil
    }

    private func clear(nextPhase: CaptionSessionPhase) {
        stopCapture()
        expiry?.cancel()
        expiry = nil
        memory.clear()
        lines = []
        origin = nil
        phase = nextPhase
        events?(.closed(interrupted: nextPhase == .interrupted))
    }
}
