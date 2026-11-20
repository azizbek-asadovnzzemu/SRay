import Foundation

/// Lifecycle state for one shared speech owner.
public enum SpeechSessionState: Equatable, Sendable {
    /// No request owns the microphone.
    case idle
    /// The user is deciding whether to grant permissions.
    case authorizing
    /// On-device recognition is active.
    case listening
    /// Capture has stopped after a content-free failure.
    case failed(SpeechFailure)
}

/// Serializes speech ownership and rejects work belonging to stopped sessions.
///
/// Create one instance at the app composition root and share it across windows.
/// Run it in a caller-owned task; cancellation and explicit stop release backend
/// resources. This type does not send text to a translation provider or persist it.
@MainActor
public final class SpeechSession {
    /// The current lifecycle state.
    public private(set) var state: SpeechSessionState = .idle
    /// The most recently delivered snapshot, cleared when capture ends.
    public private(set) var latestEvent: SpeechEvent?
    /// The single injected resource owner.
    private let backend: any SpeechBackend
    /// The identity invalidated synchronously when stop is requested.
    private var sessionID: UUID?

    /// Creates a session around one exclusively owned backend.
    public init(backend: any SpeechBackend) {
        self.backend = backend
    }

    /// Runs recognition until completion, failure, cancellation or explicit stop.
    /// Duplicate starts are ignored while a session is active.
    public func run(onEvent: @MainActor (SpeechEvent) -> Void = { _ in }) async {
        await run(onListening: {}, onEvent: onEvent)
    }

    /// Runs recognition and reports when microphone capture begins.
    public func run(
        onListening: @MainActor () -> Void,
        onEvent: @MainActor (SpeechEvent) -> Void
    ) async {
        guard sessionID == nil, !Task.isCancelled else { return }
        let id = UUID()
        sessionID = id
        latestEvent = nil
        await withTaskCancellationHandler {
            defer { finish(id: id) }
            guard backend.supportsOnDeviceRecognition else {
                state = .failed(.unavailable)
                return
            }
            state = .authorizing
            let authorized = await backend.requestAuthorization()
            guard sessionID == id, !Task.isCancelled else { return }
            guard authorized else {
                state = .failed(.permissionDenied)
                return
            }
            do {
                let events = try backend.startRecognition()
                state = .listening
                onListening()
                for try await event in events {
                    guard sessionID == id, !Task.isCancelled else { return }
                    latestEvent = event
                    onEvent(event)
                }
            } catch is CancellationError {
                // Cancellation is a normal end of capture.
            } catch {
                guard sessionID == id else { return }
                state = .failed((error as? SpeechFailure) ?? .recognitionFailed)
            }
        } onCancel: {
            // Cancellation handlers are nonisolated; identity guards prevent
            // their scheduled cleanup from terminating a newer session.
            Task { @MainActor [weak self] in self?.stop(id: id) }
        }
    }

    /// Invalidates callbacks before releasing capture resources and clearing text.
    public func stop() {
        guard let id = sessionID else { return }
        stop(id: id)
    }

    /// Stops only the matching active session.
    private func stop(id: UUID) {
        guard sessionID == id else { return }
        sessionID = nil
        latestEvent = nil
        state = .idle
        backend.stopRecognition()
    }

    /// Releases resources while preserving an explicit failure state.
    private func finish(id: UUID) {
        guard sessionID == id else { return }
        let finalState = state
        stop(id: id)
        if case .failed = finalState { state = finalState }
    }
}
