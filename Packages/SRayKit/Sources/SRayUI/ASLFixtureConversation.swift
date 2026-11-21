#if DEBUG
import ConversationCore
import Foundation
import PoseCore
import SpeechCore

/// A local geometric fixture for exercising the real conversation and playback paths.
@MainActor
public final class ASLFixtureConversation {
    public let captions: CaptionSession
    let translation: ConversationTranslation<PoseSequence>
    private let speech: ASLFixtureSpeech

    /// Creates a demo with a locally generated geometric pose.
    public init?() {
        guard let clip = try? PoseDecoder.decode(SyntheticPoseFixture.encoded()) else { return nil }
        let speech = ASLFixtureSpeech()
        let translation = ConversationTranslation<PoseSequence> { _ in
            ConversationTranslationRequest(result: { clip }, cancel: {})
        }
        self.speech = speech
        self.translation = translation
        captions = CaptionSession(backend: speech, now: { .now }, events: translation.receive)
    }

    func showSampleCaption() {
        speech.showSampleCaption()
    }
}

@MainActor
private final class ASLFixtureSpeech: SpeechBackend {
    var supportsOnDeviceRecognition: Bool { true }
    private var events: AsyncThrowingStream<SpeechEvent, Error>.Continuation?

    func requestAuthorization() async -> Bool { true }

    func startRecognition() throws -> AsyncThrowingStream<SpeechEvent, Error> {
        let pair = AsyncThrowingStream<SpeechEvent, Error>.makeStream(bufferingPolicy: .bufferingOldest(1))
        events = pair.continuation
        return pair.stream
    }

    func stopRecognition() {
        events?.finish()
        events = nil
    }

    func showSampleCaption() {
        guard let events else { return }
        self.events = nil
        let instant = ContinuousClock.now
        events.yield(SpeechEvent(
            text: "Geometric sample caption.", isFinal: true,
            sourceTiming: SpeechSourceTiming(startedAt: instant, endedAt: instant)
        ))
        events.finish()
    }
}
#endif
