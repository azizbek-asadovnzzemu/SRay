import Foundation
import SpeechCore
import Testing
@testable import ConversationCore

@MainActor
struct CaptionTranslationLimitTests {
    @Test(arguments: [CaptionTranslationLimit.textLength, .speechDuration])
    func excludedUtteranceRemainsWholeAndNeverEntersTranslation(limit: CaptionTranslationLimit) async throws {
        let origin = ContinuousClock.now
        var now = origin
        var requestCount = 0
        let translation = ConversationTranslation<String>(now: { now }) { _ in
            requestCount += 1
            return ConversationTranslationRequest(result: { "Clip" }, cancel: {})
        }
        let backend = ControlledSpeechBackend()
        let captions = CaptionSession(backend: backend, now: { now }, events: translation.receive)
        var permissions = backend.authorizationRequests.makeAsyncIterator()
        var starts = backend.recognitionStarts.makeAsyncIterator()

        captions.start()
        await permissions.next()
        backend.resolveAuthorization(true)
        await starts.next()
        translation.enable()

        let text = limit == .textLength
            ? String(repeating: "👩🏽‍💻", count: 281)
            : "Do not take the stairs."
        let startedAt = origin.advanced(by: .seconds(1))
        now = startedAt.advanced(by: limit == .speechDuration ? .seconds(16) : .seconds(1))
        backend.yield(SpeechEvent(text: text, isFinal: true, sourceTiming: .init(startedAt: startedAt, endedAt: now)))
        backend.finish()
        await captions.waitForCaptureToFinish()

        #expect(captions.lines.count == 1)
        let caption = try #require(captions.lines.first)
        #expect(caption.text == text)
        #expect(translation.presentation.captionLimits == [caption.id: limit])
        #expect(requestCount == 0)
        #expect(translation.presentation.ready == nil)
        #expect(translation.evaluation.omissions.isEmpty)

        now = origin.advanced(by: CaptionMemory.maximumAge)
        captions.expireCaptions()
        #expect(captions.lines.isEmpty)
        #expect(translation.presentation.captionLimits.isEmpty)
    }
}
