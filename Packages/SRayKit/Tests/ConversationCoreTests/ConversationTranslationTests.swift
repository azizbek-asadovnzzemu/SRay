import Foundation
import SpeechCore
import Testing
@testable import ConversationCore

@MainActor
struct ConversationTranslationTests {
    @Test func onlyStoredFinalsWithVerifiedTimingInTheCurrentWindowAreSubmitted() async throws {
        let origin = ContinuousClock.now
        var instant = origin
        var sent: [String] = []
        let translation = ConversationTranslation<String>(now: { instant }) { text in
            sent.append(text)
            return ConversationTranslationRequest(result: { "Clip" }, cancel: {})
        }
        let backend = ControlledSpeechBackend()
        let captions = CaptionSession(backend: backend, now: { instant }, events: translation.receive)
        var permissions = backend.authorizationRequests.makeAsyncIterator()
        var starts = backend.recognitionStarts.makeAsyncIterator()

        captions.start()
        await permissions.next()
        backend.resolveAuthorization(true)
        await starts.next()
        #expect(translation.presentation.state == .captionsOnly)

        instant = origin.advanced(by: .seconds(2))
        translation.enable()
        instant = origin.advanced(by: .seconds(4))
        backend.yield(SpeechEvent(text: "Earlier", isFinal: true, sourceTiming: .init(
            startedAt: origin.advanced(by: .seconds(1)), endedAt: origin.advanced(by: .seconds(3))
        )))
        backend.finish()
        await captions.waitForCaptureToFinish()
        #expect(captions.lines.last?.text == "Earlier")
        #expect(sent.isEmpty)

        captions.start()
        await permissions.next()
        backend.resolveAuthorization(true)
        await starts.next()
        backend.yield(SpeechEvent(text: "Untimed", isFinal: true))
        backend.finish()
        await captions.waitForCaptureToFinish()
        #expect(captions.lines.last?.text == "Untimed")
        #expect(sent.isEmpty)

        captions.start()
        await permissions.next()
        backend.resolveAuthorization(true)
        await starts.next()
        let source = SpeechSourceTiming(startedAt: instant, endedAt: instant)
        backend.yield(SpeechEvent(text: "Partial", isFinal: false, sourceTiming: source))
        backend.yield(SpeechEvent(text: "Fresh", isFinal: true, sourceTiming: source))
        backend.yield(SpeechEvent(text: "Duplicate", isFinal: true, sourceTiming: source))
        backend.finish()
        await captions.waitForCaptureToFinish()
        await translation.waitForRequest()

        #expect(sent == ["Fresh"])
        #expect(captions.lines.map(\.text) == ["Earlier", "Untimed", "Fresh"])
        let ready = try #require(translation.presentation.ready)
        translation.beginPlayback(for: ready.token)
        #expect(translation.presentation.playing?.translation.clip == "Clip")
        captions.interrupt()
        #expect(translation.presentation.state == .interrupted)
        #expect(translation.presentation.playing == nil)
        #expect(!translation.presentation.canReplay)
    }

    @Test func pausingCancelsInlineAndOldResultsCannotBecomeReadyAfterResume() async {
        var instant = ContinuousClock.now
        var requests = 0
        var cancellations = 0
        let started = AsyncStream<Void>.makeStream()
        let results = AsyncStream<String>.makeStream()
        let finished = AsyncStream<Void>.makeStream()
        let translation = ConversationTranslation<String>(now: { instant }) { _ in
            requests += 1
            return ConversationTranslationRequest(result: {
                started.continuation.yield(())
                var iterator = results.stream.makeAsyncIterator()
                let clip = await iterator.next() ?? "Late clip"
                finished.continuation.yield(())
                return clip
            }, cancel: { cancellations += 1 })
        }
        translation.receive(.opened(instant))
        translation.enable()
        translation.receive(.finalized("On boundary", source: .init(startedAt: instant, endedAt: instant), receivedAt: instant))
        #expect(requests == 0)
        instant = instant.advanced(by: .seconds(1))
        let startedAt = instant
        translation.receive(.finalized("Synthetic", source: .init(startedAt: instant, endedAt: instant), receivedAt: instant))
        var starts = started.stream.makeAsyncIterator()
        await starts.next()

        translation.pause()
        #expect(cancellations == 1)
        #expect(translation.presentation.state == .paused)
        instant = instant.advanced(by: .seconds(1))
        translation.enable()
        translation.receive(.finalized("Earlier window", source: .init(startedAt: startedAt, endedAt: instant), receivedAt: instant))
        #expect(requests == 1)
        results.continuation.yield("Old result")
        var completions = finished.stream.makeAsyncIterator()
        await completions.next()

        #expect(translation.presentation.state == .enabled)
        #expect(translation.presentation.ready == nil)
        translation.receive(.closed(interrupted: false))
    }
}
