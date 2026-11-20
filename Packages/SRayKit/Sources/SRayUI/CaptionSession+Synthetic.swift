#if DEBUG
import ConversationCore
import SpeechCore

extension CaptionSession {
    /// Creates local caption state for simulator UI tests without microphone or network access.
    @MainActor public static func makeSynthetic() -> CaptionSession {
        CaptionSession(backend: SyntheticSpeechBackend())
    }
}

/// Supplies a fixed input through the production speech session.
@MainActor
private final class SyntheticSpeechBackend: SpeechBackend {
    var supportsOnDeviceRecognition: Bool { true }

    func requestAuthorization() async -> Bool { true }

    func startRecognition() throws -> AsyncThrowingStream<SpeechEvent, Error> {
        AsyncThrowingStream(bufferingPolicy: .bufferingOldest(2)) { output in
            output.yield(SpeechEvent(text: "Take the elevator", isFinal: false))
            output.yield(SpeechEvent(text: "Take the elevator to the second floor.", isFinal: true))
            output.finish()
        }
    }

    func stopRecognition() {}
}
#endif
