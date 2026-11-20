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
    @ObservationIgnored private let now: @MainActor () -> ContinuousClock.Instant
    @ObservationIgnored private var memory = CaptionMemory()
    private var origin: ContinuousClock.Instant?
    @ObservationIgnored private var capture: Task<Void, Never>?
    @ObservationIgnored private var expiry: Task<Void, Never>?
    @ObservationIgnored private var requestID: UUID?

    /// Creates a room for local captions around one exclusively owned microphone backend.
    public init(backend: any SpeechBackend) {
        speech = SpeechSession(backend: backend)
        now = { .now }
    }

    /// Creates a session with a testable monotonic time source.
    init(backend: any SpeechBackend, now: @escaping @MainActor () -> ContinuousClock.Instant) {
        speech = SpeechSession(backend: backend)
        self.now = now
    }

    /// Starts or continues captions after an explicit user action.
    public func start() {
        guard requestID == nil else { return }
        let instant = now()
        let origin = origin ?? instant
        self.origin = origin
        let id = UUID()
        let startedAt = origin.duration(to: instant)
        requestID = id
        phase = .preparing
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

    /// Stops capture and releases the conversation when the app moves to the background.
    public func interrupt() {
        guard origin != nil else { return }
        clear(nextPhase: .interrupted)
    }

    /// Waits for the current recognition request to finish, if one is active.
    func waitForCaptureToFinish() async {
        await capture?.value
    }

    /// Removes expired captions even when speech has stopped.
    func expireCaptions() {
        guard let origin else { return }
        lines = memory.snapshot(at: origin.duration(to: now()))
        scheduleExpiry()
    }

    private func receive(_ event: SpeechEvent, id: UUID, startedAt: Duration) {
        guard requestID == id, let origin else { return }
        let elapsed = origin.duration(to: now())
        let result = memory.update(id: id, text: event.text, isFinal: event.isFinal, startedAt: startedAt, now: elapsed)
        lines = memory.snapshot(at: elapsed)
        scheduleExpiry()
        if result == .rejectedOversize {
            stopCapture()
            phase = .oversized
        }
    }

    private func finishRequest(id: UUID) {
        guard requestID == id else { return }
        requestID = nil
        capture = nil
        if case .failed(let reason) = speech.state {
            phase = .failed(reason)
        } else {
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
    }
}
