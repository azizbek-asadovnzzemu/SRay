import Foundation
import Testing
@testable import ConversationCore

@MainActor
struct TranslationPipelineTests {
    @Test func pauseClosesTheWindowBeforeCancellationAndResumeDoesNotSendEarlierSpeech() throws {
        let transport = Transport()
        let pipeline = transport.makePipeline()
        let sessionID = try #require(pipeline.startConversation())
        var ledger = UtteranceLedger(sessionID: sessionID)
        #expect(pipeline.startConversation() == nil)
        let beganEarlier = ledger.begin(sequence: 1, startedAt: .zero, window: pipeline.currentWindow)
        #expect(beganEarlier)
        #expect(pipeline.enableASL(at: .seconds(1)))
        let earlierFinal = ledger.finalize(
            sequence: 1, text: "Earlier speech", endedAt: .seconds(2), window: pipeline.currentWindow
        )
        let earlier = try #require(earlierFinal)
        #expect(pipeline.enqueue(earlier, finalizedAt: .seconds(2), at: .seconds(2)).isEmpty)
        #expect(transport.requests.isEmpty)
        try enqueue(2, in: pipeline, ledger: &ledger)
        try enqueue(3, in: pipeline, ledger: &ledger)
        let first = try #require(transport.requests.first?.token)
        let originalWindow = try #require(pipeline.currentWindow)
        transport.onCancel = { token in
            #expect(pipeline.state == .paused)
            #expect(pipeline.waitingCount == 0)
            #expect(pipeline.receive("Late", for: token, at: .seconds(100)).isEmpty)
        }
        #expect(pipeline.pauseASL() == [
            .init(sequence: 2, reason: .cancelled),
            .init(sequence: 3, reason: .cancelled)
        ])
        #expect(transport.cancellations == [first])
        #expect(pipeline.enableASL(at: .seconds(4)))
        #expect(pipeline.currentWindow != originalWindow)
        let beganCrossing = ledger.begin(sequence: 4, startedAt: .seconds(3), window: originalWindow)
        #expect(beganCrossing)
        let crossingFinal = ledger.finalize(
            sequence: 4, text: "Crossed pause", endedAt: .seconds(4), window: pipeline.currentWindow
        )
        let crossing = try #require(crossingFinal)
        #expect(pipeline.enqueue(crossing, finalizedAt: .seconds(4), at: .seconds(4)).isEmpty)
        try enqueue(5, in: pipeline, ledger: &ledger)
        #expect(transport.requests.map(\.token.sequence) == [2, 5])
        #expect(pipeline.receive("Old window", for: first, at: .seconds(100)).isEmpty)
        #expect(pipeline.waitingCount == 1)
        #expect(pipeline.readyForPlayback == nil)
        transport.onCancel = nil
    }

    @Test func readyClipHoldsCapacityUntilItsFirstFrameAndActivePlaybackKeepsItsPlace() throws {
        let transport = Transport()
        let pipeline = transport.makePipeline()
        var ledger = try startEnabled(pipeline)
        try enqueue(1, in: pipeline, ledger: &ledger)
        try enqueue(2, in: pipeline, ledger: &ledger)
        #expect(try enqueue(3, in: pipeline, ledger: &ledger) == [.init(sequence: 3, reason: .capacity)])
        let first = try #require(transport.requests.first?.token)

        #expect(pipeline.receive("First clip", for: first, at: .seconds(3)).isEmpty)
        #expect(pipeline.waitingCount == 2)
        #expect(transport.requests.count == 1)
        #expect(pipeline.readyForPlayback?.clip == "First clip")
        #expect(pipeline.beginPlayback(for: first, at: .seconds(3)).started)

        #expect(transport.requests.map(\.token.sequence) == [1, 2])
        let second = try #require(transport.requests.last?.token)
        #expect(pipeline.receive("Second clip", for: second, at: .seconds(3)).isEmpty)
        #expect(pipeline.readyForPlayback == nil)
        try enqueue(4, in: pipeline, ledger: &ledger)
        #expect(pipeline.waitingCount == 2)
        #expect(pipeline.nextExpiry == .seconds(12))
        #expect(pipeline.advance(to: .seconds(12)) == [.init(sequence: 2, reason: .expired)])
        #expect(pipeline.playing == first)
        #expect(transport.requests.map(\.token.sequence) == [1, 2, 4])
    }

    @Test func deadlineCancelsInFlightWorkAndAlsoAppliesUntilTheFirstFrame() throws {
        let transport = Transport()
        let pipeline = transport.makePipeline()
        var ledger = try startEnabled(pipeline)
        try enqueue(1, in: pipeline, ledger: &ledger)
        try enqueue(2, in: pipeline, ledger: &ledger)
        let first = try #require(transport.requests.first?.token)
        transport.onCancel = { token in
            #expect(pipeline.receive("Expired callback", for: token, at: .seconds(100)).isEmpty)
        }

        #expect(pipeline.nextExpiry == .seconds(11))
        #expect(pipeline.advance(to: .seconds(11)) == [.init(sequence: 1, reason: .expired)])
        #expect(transport.cancellations == [first])
        #expect(transport.requests.map(\.token.sequence) == [1, 2])
        let second = try #require(transport.requests.last?.token)
        #expect(pipeline.receive("Second clip", for: second, at: .seconds(11)).isEmpty)
        let display = pipeline.beginPlayback(for: second, at: .seconds(12))
        #expect(!display.started)
        #expect(display.omissions == [.init(sequence: 2, reason: .expired)])
        #expect(pipeline.readyForPlayback == nil)
        #expect(pipeline.playing == nil)
        #expect(pipeline.nextExpiry == nil)
        transport.onCancel = nil
    }

    @Test func transportFailureStopsPlaybackAndDiscardsQueuedTextUntilExplicitResume() throws {
        let transport = Transport()
        let pipeline = transport.makePipeline()
        var ledger = try startEnabled(pipeline)
        try enqueue(1, in: pipeline, ledger: &ledger)
        try enqueue(2, in: pipeline, ledger: &ledger)
        let first = try #require(transport.requests.first?.token)
        _ = pipeline.receive("First clip", for: first, at: .seconds(2))
        #expect(pipeline.beginPlayback(for: first, at: .seconds(2)).started)
        try enqueue(3, in: pipeline, ledger: &ledger)
        let second = try #require(transport.requests.last?.token)

        #expect(pipeline.requestFailed(for: second, at: .seconds(3)) == [
            .init(sequence: 2, reason: .requestFailed),
            .init(sequence: 3, reason: .cancelled)
        ])
        #expect(pipeline.state == .paused)
        #expect(pipeline.playing == nil)
        #expect(pipeline.waitingCount == 0)
        #expect(pipeline.advance(to: .seconds(4)).isEmpty)
        #expect(transport.requests.map(\.token.sequence) == [1, 2])
        #expect(pipeline.enableASL(at: .seconds(4)))
        try enqueue(5, in: pipeline, ledger: &ledger)
        #expect(transport.requests.map(\.token.sequence) == [1, 2, 5])
    }

    @Test func callbacksFromAnEndedConversationCannotTouchPlaybackOrTimeInTheNextOne() throws {
        let transport = Transport()
        let pipeline = transport.makePipeline()
        var ledger = try startEnabled(pipeline)
        try enqueue(1, in: pipeline, ledger: &ledger)
        let previous = try #require(transport.requests.last?.token)
        pipeline.interrupt()
        #expect(pipeline.state == .interrupted)
        #expect(!pipeline.enableASL(at: .seconds(2)))
        #expect(transport.cancellations == [previous])

        ledger = try startEnabled(pipeline)
        try enqueue(1, in: pipeline, ledger: &ledger)
        let current = try #require(transport.requests.last?.token)
        #expect(current.sessionID != previous.sessionID)
        #expect(pipeline.receive("New clip", for: current, at: .seconds(1)).isEmpty)
        #expect(!pipeline.beginPlayback(for: previous, at: .seconds(100)).started)
        #expect(pipeline.beginPlayback(for: current, at: .seconds(1)).started)
        #expect(pipeline.finishPlayback(for: previous, at: .seconds(100)).isEmpty)
        #expect(pipeline.playing == current)
        #expect(pipeline.finishPlayback(for: current, at: .seconds(2)).isEmpty)
        #expect(pipeline.playing == nil)
        pipeline.endConversation()
        #expect(pipeline.state == .idle)
    }

    private func startEnabled(_ pipeline: TranslationPipeline<String>) throws -> UtteranceLedger {
        let id = try #require(pipeline.startConversation())
        try #require(pipeline.enableASL(at: .zero))
        return UtteranceLedger(sessionID: id)
    }

    @discardableResult
    private func enqueue(
        _ sequence: UInt64, in pipeline: TranslationPipeline<String>, ledger: inout UtteranceLedger
    ) throws -> [TranslationOmission] {
        let time = Duration.seconds(Int64(sequence))
        let window = try #require(pipeline.currentWindow)
        let began = ledger.begin(sequence: sequence, startedAt: time, window: window)
        try #require(began)
        let finalized = ledger.finalize(
            sequence: sequence, text: "Synthetic speech", endedAt: time, window: window
        )
        let utterance = try #require(finalized)
        return pipeline.enqueue(utterance, finalizedAt: time, at: time)
    }

    @MainActor
    private final class Transport {
        private(set) var requests: [(text: String, token: SubmissionToken)] = []
        private(set) var cancellations: [SubmissionToken] = []
        var onCancel: ((SubmissionToken) -> Void)?

        func makePipeline() -> TranslationPipeline<String> {
            TranslationPipeline(
                startSubmission: { [self] in requests.append((text: $0, token: $1)) },
                cancelSubmission: { [self] token in
                    cancellations.append(token)
                    onCancel?(token)
                }
            )
        }
    }
}
