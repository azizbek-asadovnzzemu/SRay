import Foundation
import SpeechCore
import Testing
@testable import ConversationCore

@MainActor
struct ConversationRateLimitTests {
    @Test(arguments: [false, true])
    func rateLimitKeepsTheGateClosedUntilExplicitResume(responseArrivesAtExpiry: Bool) async {
        struct RateLimited: TranslationRetryAdvising {
            func retryDelay(relativeTo date: Date) -> Duration? { .seconds(2) }
        }

        let origin = ContinuousClock.now
        var instant = origin
        var submissions: [String] = []
        let response = AsyncStream<Void>.makeStream()
        let translation = ConversationTranslation<String>(now: { instant }) { text in
            submissions.append(text)
            return ConversationTranslationRequest(result: {
                if text == "First" {
                    var iterator = response.stream.makeAsyncIterator()
                    await iterator.next()
                    throw RateLimited()
                }
                return "Sample pose"
            }, cancel: {})
        }
        translation.receive(.opened(origin))
        translation.enable()
        let firstID = submit("First", at: .seconds(1))
        let secondID = submit("Queued", at: .seconds(2))
        let failureTime: Duration = responseArrivesAtExpiry ? .seconds(11) : .seconds(3)
        instant = origin.advanced(by: failureTime)

        response.continuation.yield(())
        response.continuation.finish()
        await translation.waitForRequest()

        #expect(translation.presentation.state == .paused)
        #expect(translation.presentation.isWaitingForRetry)
        #expect(translation.presentation.omissions[firstID] == (responseArrivesAtExpiry ? .expired : .requestFailed))
        #expect(translation.presentation.omissions[secondID] == .cancelled)
        #expect(submissions == ["First"])

        // Reopening captions must not bypass a process-local provider deadline.
        translation.receive(.closed(interrupted: false))
        instant = origin.advanced(by: failureTime + .seconds(1))
        translation.receive(.opened(instant))
        translation.enable()
        _ = submit("During cooldown", at: failureTime + .milliseconds(1_500))
        #expect(translation.presentation.state == .captionsOnly)
        #expect(translation.presentation.isWaitingForRetry)
        #expect(submissions == ["First"])

        _ = submit("Before explicit resume", at: failureTime + .seconds(2))
        #expect(translation.presentation.state == .captionsOnly)
        #expect(!translation.presentation.isWaitingForRetry)
        translation.enable()
        _ = submit("Fresh", at: failureTime + .seconds(3))
        await translation.waitForRequest()
        #expect(translation.presentation.state == .enabled)
        #expect(translation.presentation.ready?.clip == "Sample pose")
        #expect(submissions == ["First", "Fresh"])
        translation.receive(.closed(interrupted: false))

        func submit(_ text: String, at elapsed: Duration) -> UUID {
            instant = origin.advanced(by: elapsed)
            let id = UUID()
            translation.receive(.finalized(
                id: id, text, source: .init(startedAt: instant, endedAt: instant), receivedAt: instant
            ))
            return id
        }
    }
}
