#if DEBUG
import Foundation

/// A controllable backend for deterministic lifecycle tests, never used for capture.
@MainActor
public final class ControlledSpeechBackend: SpeechBackend {
    /// The capability returned to the session under test.
    public var supportsOnDeviceRecognition = true
    /// Number of recognition starts, used to verify exclusive ownership.
    public private(set) var startCount = 0
    /// Number of cleanup requests.
    public private(set) var stopCount = 0
    /// A setup failure injected after permission succeeds.
    public var startFailure: SpeechFailure?
    /// Signals a pending authorization without wall-clock sleeps.
    public let authorizationRequests: AsyncStream<Void>
    /// Signals when capture setup has completed.
    public let recognitionStarts: AsyncStream<Void>
    /// The producer for recognition signals.
    private let startSignal: AsyncStream<Void>.Continuation
    /// The producer for authorization signals.
    private let requestSignal: AsyncStream<Void>.Continuation
    /// Suspended authorization callbacks, allowing stop/restart races.
    private var permissions: [CheckedContinuation<Bool, Never>] = []
    /// The producer for the active recognition stream.
    private var events: AsyncThrowingStream<SpeechEvent, Error>.Continuation?

    /// Creates an isolated backend with bounded event storage.
    public init() {
        (recognitionStarts, startSignal) = AsyncStream.makeStream(bufferingPolicy: .bufferingOldest(8))
        (authorizationRequests, requestSignal) = AsyncStream.makeStream(bufferingPolicy: .bufferingOldest(8))
    }

    /// Suspends until the test resolves the next permission request.
    public func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            permissions.append(continuation)
            requestSignal.yield(())
        }
    }

    /// Resolves the oldest outstanding permission request.
    public func resolveAuthorization(_ granted: Bool) {
        precondition(!permissions.isEmpty)
        permissions.removeFirst().resume(returning: granted)
    }

    /// Starts a bounded stream or throws the injected setup failure.
    public func startRecognition() throws -> AsyncThrowingStream<SpeechEvent, Error> {
        if let startFailure { throw startFailure }
        startCount += 1
        let pair = AsyncThrowingStream<SpeechEvent, Error>.makeStream(bufferingPolicy: .bufferingOldest(8))
        events = pair.continuation
        startSignal.yield(())
        return pair.stream
    }

    /// Ends the active stream and records resource cleanup.
    public func stopRecognition() {
        stopCount += 1
        events?.finish()
        events = nil
    }

    /// Delivers a bounded snapshot or fails explicitly on overflow.
    public func yield(_ event: SpeechEvent) {
        if case .dropped = events?.yield(event) {
            events?.finish(throwing: SpeechFailure.overloaded)
        }
    }

    /// Finishes recognition with an optional typed failure.
    public func finish(throwing failure: SpeechFailure? = nil) {
        events?.finish(throwing: failure)
    }
}
#endif
