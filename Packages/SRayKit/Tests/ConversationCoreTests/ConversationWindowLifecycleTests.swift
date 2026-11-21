import Foundation
import SpeechCore
import Testing
@testable import ConversationCore

@MainActor
struct ConversationWindowLifecycleTests {
    @Test func lastWindowCancelsInFlightTranslationAndLateResultCannotReplaceNextSession() async throws {
        var now = ContinuousClock.now
        var requests: [String: CheckedContinuation<String, Never>] = [:]
        var cancellations: [String] = []
        let started = AsyncStream<String>.makeStream()
        let waiterStarted = AsyncStream<Void>.makeStream()
        let translation = ConversationTranslation<String>(now: { now }) { text in
            ConversationTranslationRequest(result: {
                // This transport deliberately completes even if its observer is cancelled.
                await withCheckedContinuation { continuation in
                    requests[text] = continuation
                    started.continuation.yield(text)
                }
            }, cancel: {
                cancellations.append(text)
            })
        }
        let backend = ControlledSpeechBackend()
        let captions = CaptionSession(backend: backend, now: { now }, events: translation.receive)
        var requestStarts = started.stream.makeAsyncIterator()
        var waiterStarts = waiterStarted.stream.makeAsyncIterator()
        let firstWindow = UUID()
        let otherWindow = UUID()
        defer {
            for request in requests.values { request.resume(returning: "Abandoned result") }
        }

        captions.windowDidOpen(firstWindow)
        captions.windowDidOpen(otherWindow)
        await capture("Old caption")
        let oldStarted = await requestStarts.next()
        #expect(oldStarted == "Old caption")
        let oldObserver = Task { @MainActor in
            waiterStarted.continuation.yield(())
            await translation.waitForRequest()
        }
        await waiterStarts.next()

        captions.windowDidClose(firstWindow)
        #expect(captions.lines.first?.text == "Old caption")
        #expect(translation.presentation.state == .enabled)
        #expect(cancellations.isEmpty)

        captions.windowDidClose(otherWindow)
        #expect(captions.lines.isEmpty)
        #expect(translation.presentation.state == .interrupted)
        #expect(cancellations == ["Old caption"])

        let newWindow = UUID()
        captions.windowDidOpen(newWindow)
        await capture("New caption")
        let newStarted = await requestStarts.next()
        #expect(newStarted == "New caption")

        let oldResult = requests.removeValue(forKey: "Old caption")
        try #require(oldResult).resume(returning: "Late old result")
        await oldObserver.value
        #expect(translation.presentation.ready == nil)
        #expect(captions.lines.map { $0.text } == ["New caption"])

        let newResult = requests.removeValue(forKey: "New caption")
        try #require(newResult).resume(returning: "Current result")
        await translation.waitForRequest()
        #expect(translation.presentation.ready?.clip == "Current result")
        #expect(cancellations == ["Old caption"])
        captions.windowDidClose(newWindow)

        @MainActor func capture(_ text: String) async {
            var permissions = backend.authorizationRequests.makeAsyncIterator()
            var captureStarts = backend.recognitionStarts.makeAsyncIterator()
            captions.start()
            await permissions.next()
            backend.resolveAuthorization(true)
            await captureStarts.next()
            #expect(translation.presentation.state == .captionsOnly)
            translation.enable()
            now = now.advanced(by: .seconds(1))
            backend.yield(SpeechEvent(text: text, isFinal: true, sourceTiming: .init(startedAt: now, endedAt: now)))
            backend.finish()
            await captions.waitForCaptureToFinish()
        }
    }
}
