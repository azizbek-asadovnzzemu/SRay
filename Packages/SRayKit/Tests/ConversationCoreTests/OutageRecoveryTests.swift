import Foundation
import SpeechCore
import Testing
@testable import ConversationCore

/// Uses the production caption session and translation pipeline with synthetic inputs.
@MainActor
struct OutageRecoveryTests {
    @Test func providerFailureKeepsCaptionsAvailableUntilExplicitTranslationResume() async throws {
        let backend = ControlledSpeechBackend()
        let captions = CaptionSession(backend: backend)
        var permissions = backend.authorizationRequests.makeAsyncIterator()
        var starts = backend.recognitionStarts.makeAsyncIterator()

        var requests: [(text: String, token: SubmissionToken)] = []
        let pipeline = TranslationPipeline<String>(
            startSubmission: { text, token in requests.append((text, token)) },
            cancelSubmission: { _ in }
        )
        let conversation = try #require(pipeline.startConversation())
        var ledger = UtteranceLedger(sessionID: conversation)
        captions.start()
        await permissions.next()
        backend.resolveAuthorization(true)
        await starts.next()
        defer {
            captions.end()
            pipeline.endConversation()
        }

        let local = try finalizedCaption(1, in: &ledger, window: pipeline.currentWindow)
        #expect(pipeline.enqueue(local, finalizedAt: .seconds(1), at: .seconds(1)).isEmpty)
        #expect(requests.isEmpty)

        try #require(pipeline.enableASL(at: .seconds(1)))
        let sent = try finalizedCaption(2, in: &ledger, window: pipeline.currentWindow)
        _ = pipeline.enqueue(sent, finalizedAt: .seconds(2), at: .seconds(2))
        let token = try #require(requests.last?.token)
        let waiting = try finalizedCaption(3, in: &ledger, window: pipeline.currentWindow)
        _ = pipeline.enqueue(waiting, finalizedAt: .seconds(3), at: .seconds(3))

        let omissions = pipeline.requestFailed(for: token, at: .seconds(3))
        #expect(omissions == [.init(sequence: 2, reason: .requestFailed), .init(sequence: 3, reason: .cancelled)])
        #expect(pipeline.state == .paused)
        #expect(captions.phase == .listening)
        #expect(backend.stopCount == 0)

        let duringOutage = try finalizedCaption(4, in: &ledger, window: pipeline.currentWindow)
        _ = pipeline.enqueue(duringOutage, finalizedAt: .seconds(4), at: .seconds(4))
        _ = pipeline.advance(to: .seconds(5))
        backend.yield(SpeechEvent(text: duringOutage.text, isFinal: true))
        backend.finish()
        await captions.waitForCaptureToFinish()

        #expect(requests.map(\.token.sequence) == [2])
        #expect(captions.lines.map(\.text) == [duringOutage.text])
        #expect(captions.lines.first?.isFinal == true)
        #expect(captions.canEnd)

        try #require(pipeline.enableASL(at: .seconds(5)))
        #expect(pipeline.receive("Old pose", for: token, at: .seconds(5)).isEmpty)
        #expect(pipeline.readyForPlayback == nil)
        let fresh = try finalizedCaption(6, in: &ledger, window: pipeline.currentWindow)
        _ = pipeline.enqueue(fresh, finalizedAt: .seconds(6), at: .seconds(6))

        #expect(requests.map(\.token.sequence) == [2, 6])
        #expect(requests.last?.token.windowID != token.windowID)
        #expect(requests.map(\.text) == [sent.text, fresh.text])
    }

    private func finalizedCaption(
        _ sequence: UInt64, in ledger: inout UtteranceLedger, window: TranslationWindow?
    ) throws -> FinalizedUtterance {
        let time = Duration.seconds(Int64(sequence))
        let began = ledger.begin(sequence: sequence, startedAt: time, window: window)
        try #require(began)
        let finalized = ledger.finalize(sequence: sequence, text: "Synthetic caption \(sequence)", endedAt: time, window: window)
        return try #require(finalized)
    }
}
