import Foundation
import SpeechCore
import Testing
@testable import ConversationCore

@MainActor
struct ConversationPlaybackClockTests {
    @Test func playbackKeepsOneStartAndReplayGetsAFreshStart() async throws {
        let origin = ContinuousClock.now
        var now = origin
        let translation = ConversationTranslation<String>(now: { now }) { _ in
            ConversationTranslationRequest(result: { "Clip" }, cancel: {})
        }
        translation.receive(.opened(origin))
        translation.enable()
        now = origin.advanced(by: .seconds(1))
        translation.receive(.finalized(
            id: UUID(), "Sample", source: .init(startedAt: now, endedAt: now), receivedAt: now
        ))
        await translation.waitForRequest()
        let ready = try #require(translation.presentation.ready)

        now = origin.advanced(by: .seconds(2))
        translation.beginPlayback(for: ready.token)
        let live = try #require(translation.presentation.playing)
        #expect(translation.presentation.playbackStartedAt == nil)
        let liveStart = origin.advanced(by: .milliseconds(2_100))
        now = liveStart
        translation.attachPlaybackView(id: live.id)
        #expect(translation.presentation.playbackStartedAt == liveStart)
        now = origin.advanced(by: .seconds(3))
        translation.attachPlaybackView(id: live.id)
        translation.receive(.retainedCaptions([]))
        #expect(translation.presentation.playbackStartedAt == liveStart)

        translation.finishPlayback(id: live.id)
        #expect(translation.presentation.playbackStartedAt == nil)
        now = origin.advanced(by: .seconds(4))
        translation.replay()
        let replay = try #require(translation.presentation.playing)
        #expect(replay.id != live.id)
        translation.attachPlaybackView(id: live.id)
        #expect(translation.presentation.playbackStartedAt == nil)
        let replayStart = origin.advanced(by: .milliseconds(4_100))
        now = replayStart
        translation.attachPlaybackView(id: replay.id)
        #expect(translation.presentation.playbackStartedAt == replayStart)

        translation.finishPlayback(id: live.id)
        #expect(translation.presentation.playing?.id == replay.id)
        #expect(translation.presentation.playbackStartedAt == replayStart)
        translation.receive(.closed(interrupted: true))
        #expect(translation.presentation.playbackStartedAt == nil)
    }
}
