import Foundation

/// A recognition snapshot scoped to one backend recognition request.
public struct SpeechEvent: Equatable, Sendable {
    /// Recognized text, held only in memory by the session owner.
    public let text: String
    /// Whether recognition has finalized this snapshot.
    public let isFinal: Bool

    /// Creates an immutable recognition snapshot.
    public init(text: String, isFinal: Bool) {
        self.text = text
        self.isFinal = isFinal
    }
}

/// Content-free failures suitable for conversation state and diagnostics.
public enum SpeechFailure: Error, Equatable, Sendable {
    /// The selected locale or device cannot perform on-device recognition.
    case unavailable
    /// Microphone or speech permission was not granted.
    case permissionDenied
    /// Recognition or capture failed without exposing a framework error message.
    case recognitionFailed
    /// A bounded event stream overflowed rather than silently dropping final text.
    case overloaded
    /// A system interruption or audio route change ended capture.
    case interrupted
}

/// Owns a single microphone and on-device recognition request.
///
/// Implementations must never fall back to remote speech recognition. A stream
/// must be bounded and finish with an explicit error if a final result would
/// otherwise be dropped. All resource operations are serialized on the main actor.
@MainActor
public protocol SpeechBackend: AnyObject {
    /// Whether an offline recognition attempt is supported, not proof of runtime success.
    var supportsOnDeviceRecognition: Bool { get }
    /// Requests microphone and speech permission in response to an explicit start.
    func requestAuthorization() async -> Bool
    /// Starts one on-device request, returning bounded recognition events.
    /// - Throws: A content-free failure if setup cannot complete.
    func startRecognition() throws -> AsyncThrowingStream<SpeechEvent, Error>
    /// Idempotently removes taps, ends/cancels recognition and releases owned audio resources.
    func stopRecognition()
}
