#if DEBUG
import ConversationCore
import Foundation
import Observation
import PoseCore
import SpeechCore

/// A local geometric fixture for exercising the real conversation and playback paths.
@MainActor @Observable
public final class ASLFixtureConversation {
    public let captions: CaptionSession
    let translation: ConversationTranslation<PoseSequence>
    /// The selected output preference shared by the demo windows.
    private(set) var outputMode: ASLFixtureOutputMode = .captionsOnly
    private let speech: ASLFixtureSpeech
    private let onAuditCompletion: (@MainActor () -> Void)?

    /// Whether this Debug fixture was launched to run the standalone privacy audit.
    public var isRunningAudit: Bool { onAuditCompletion != nil }

    /// Creates a demo with a locally generated geometric pose.
    public init?(
        failsFirstRequest: Bool = false,
        usesOverLimitSample: Bool = false,
        onAuditCompletion: (@MainActor () -> Void)? = nil
    ) {
        guard let clip = try? PoseDecoder.decode(SyntheticPoseFixture.encoded()) else { return nil }
        let sampleText = usesOverLimitSample
            ? String(repeating: "Sample ", count: 39) + "Do not take the stairs."
            : "Geometric sample caption."
        let speech = ASLFixtureSpeech(sampleText: sampleText)
        var shouldFail = failsFirstRequest
        let translation = ConversationTranslation<PoseSequence> { _ in
            if shouldFail {
                shouldFail = false
                throw SampleRequestUnavailable()
            }
            return ConversationTranslationRequest(result: { clip }, cancel: {})
        }
        self.speech = speech
        self.onAuditCompletion = onAuditCompletion
        self.translation = translation
        captions = CaptionSession(backend: speech, now: { .now }, events: translation.receive)
    }

    /// Keeps a caption fallback available whenever the demo is paused or off.
    var showsCaptions: Bool {
        outputMode != .poseOnly || translation.presentation.state != .enabled
    }

    /// Applies a presentation choice. Captions Only also pauses the demo.
    func selectOutput(_ mode: ASLFixtureOutputMode) {
        outputMode = mode
        if mode == .captionsOnly { translation.pause() }
    }

    /// Opens a new demo window for future captions after an explicit action.
    func enableDemo() {
        translation.enable()
        if translation.presentation.state == .enabled && outputMode == .captionsOnly {
            outputMode = .captionsAndPose
        }
    }

    func showSampleCaption() {
        speech.showSampleCaption()
    }

    /// Runs one sample only when the explicitly selected audit has started listening.
    func submitAuditSample() async {
        guard isRunningAudit, captions.phase == .listening else { return }
        enableDemo()
        do {
            try await Task.sleep(for: .milliseconds(1))
        } catch {
            return
        }
        guard captions.phase == .listening else { return }
        showSampleCaption()
    }

    /// Ends the audit after the result has been rendered and reached the replay slot.
    func finishPlayback(id: UUID) {
        translation.finishPlayback(id: id)
        if let onAuditCompletion, translation.presentation.canReplay {
            captions.end()
            onAuditCompletion()
        }
    }
}

private struct SampleRequestUnavailable: Error {}

@MainActor
private final class ASLFixtureSpeech: SpeechBackend {
    let sampleText: String
    var supportsOnDeviceRecognition: Bool { true }
    private var events: AsyncThrowingStream<SpeechEvent, Error>.Continuation?

    init(sampleText: String) {
        self.sampleText = sampleText
    }

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
            text: sampleText, isFinal: true,
            sourceTiming: SpeechSourceTiming(startedAt: instant, endedAt: instant)
        ))
        events.finish()
    }
}
#endif
