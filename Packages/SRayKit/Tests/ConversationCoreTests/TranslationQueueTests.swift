import Foundation
import Testing
@testable import ConversationCore

/// Exercises queue behavior using synthetic clips and an explicit monotonic clock.
struct TranslationQueueTests {
    /// A ready clip occupies capacity and blocks the next request until its first frame.
    @Test func capacityIncludesEveryWaitingStage() throws {
        // Arrange
        var queue = TranslationQueue<Int>(sessionID: UUID(), windowID: UUID())
        let one = makeUtterance(1, for: queue)
        let two = makeUtterance(2, for: queue)
        let three = makeUtterance(3, for: queue)

        // Act
        let firstAdmission = queue.enqueue(one, finalizedAt: .zero)
        let firstRequest = queue.takeNextRequest()
        let secondAdmission = queue.enqueue(two, finalizedAt: .zero)
        let firstResponse = queue.accept(101, for: 1)
        let fullAdmission = queue.enqueue(three, finalizedAt: .zero)
        let blockedRequest = queue.takeNextRequest()

        // Assert
        #expect(firstAdmission == .queued)
        #expect(secondAdmission == .queued)
        #expect(firstRequest?.sequence == 1)
        #expect(firstResponse)
        #expect(fullAdmission == .omitted(.init(sequence: 3, reason: .capacity)))
        #expect(blockedRequest == nil)
        #expect(queue.waitingCount == 2)
        #expect(queue.readyForPlayback?.clip == 101)
        let firstFrame = queue.markFirstFrame(for: 1)
        #expect(firstFrame)
        #expect(queue.playingSequence == 1)
        let secondRequest = queue.takeNextRequest()
        #expect(secondRequest?.sequence == 2)
        #expect(queue.waitingCount == 1)
    }

    /// A translated clip waiting behind slow playback expires without interrupting it.
    @Test func readyClipExpiresWhileEarlierClipPlays() {
        // Arrange
        var queue = TranslationQueue<Int>(sessionID: UUID(), windowID: UUID())
        queue.enqueueForTest(1)
        _ = queue.takeNextRequest()
        queue.accept(101, for: 1)
        queue.markFirstFrame(for: 1)
        queue.enqueueForTest(2)
        _ = queue.takeNextRequest()
        queue.accept(102, for: 2)

        // Act
        let early = queue.advance(to: .milliseconds(9_999))
        let expired = queue.advance(to: .seconds(10))
        let lateFrame = queue.markFirstFrame(for: 2)

        // Assert
        #expect(early.isEmpty)
        #expect(expired == [.init(sequence: 2, reason: .expired)])
        #expect(lateFrame == false)
        #expect(queue.playingSequence == 1)
    }

    /// Expiry clears queued and in-flight work, and rejects a late network callback.
    @Test func expiresInFlightAndQueuedWorkTogether() {
        // Arrange
        var queue = TranslationQueue<Int>(sessionID: UUID(), windowID: UUID())
        queue.enqueueForTest(1)
        _ = queue.takeNextRequest()
        queue.enqueueForTest(2)

        // Act
        let expired = queue.advance(to: .seconds(10))
        let late = queue.accept(101, for: 1)

        // Assert
        #expect(expired == [.init(sequence: 1, reason: .expired), .init(sequence: 2, reason: .expired)])
        #expect(late == false)
        #expect(queue.waitingCount == 0)
        #expect(queue.nextExpiry == nil)
    }

    /// Pause disposes of waiting work and permanently invalidates an old epoch.
    @Test func closedWindowRejectsReplay() {
        // Arrange
        var queue = TranslationQueue<Int>(sessionID: UUID(), windowID: UUID())
        queue.enqueueForTest(1)
        _ = queue.takeNextRequest()
        queue.enqueueForTest(2)
        let three = makeUtterance(3, for: queue)

        // Act
        let cancelled = queue.close()
        let stale = queue.accept(101, for: 1)
        let replay = queue.enqueue(three, finalizedAt: .zero)

        // Assert
        #expect(cancelled == [.init(sequence: 1, reason: .cancelled), .init(sequence: 2, reason: .cancelled)])
        #expect(stale == false)
        #expect(replay == .ignored)
        #expect(queue.waitingCount == 0)
    }

    /// Out-of-window input cannot consume a slot or advance the sequence watermark.
    @Test func foreignWindowCannotDisplaceCurrentCaption() {
        // Arrange
        var queue = TranslationQueue<Int>(sessionID: UUID(), windowID: UUID())
        let foreign = FinalizedUtterance(sessionID: queue.sessionID, sequence: 100, text: "Synthetic",
                                         eligibility: .eligible(windowID: UUID()))

        // Act
        let rejected = queue.enqueue(foreign, finalizedAt: .zero)
        let valid = queue.enqueue(makeUtterance(1, for: queue), finalizedAt: .zero)

        // Assert
        #expect(rejected == .ignored)
        #expect(valid == .queued)
        #expect(queue.waitingCount == 1)
    }

    private func makeUtterance(_ sequence: UInt64, for queue: TranslationQueue<Int>) -> FinalizedUtterance {
        FinalizedUtterance(sessionID: queue.sessionID, sequence: sequence, text: "Synthetic",
                           eligibility: .eligible(windowID: queue.windowID))
    }
}

private extension TranslationQueue where Clip == Int {
    mutating func enqueueForTest(_ sequence: UInt64) {
        let utterance = FinalizedUtterance(sessionID: sessionID, sequence: sequence, text: "Synthetic",
                                            eligibility: .eligible(windowID: windowID))
        _ = enqueue(utterance, finalizedAt: .zero)
    }
}
