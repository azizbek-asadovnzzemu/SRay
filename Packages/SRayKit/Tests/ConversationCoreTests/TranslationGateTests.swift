import Foundation
import Testing
@testable import ConversationCore

/// Tests dispatch ordering on the same actor as production state changes.
@MainActor
struct TranslationGateTests {
    /// Every conversation begins with captions only and rejects duplicate window starts.
    @Test func startsClosedAndSharesOneConversation() throws {
        // Arrange
        let gate = TranslationGate(cancelSubmission: { _ in })
        // Act
        let id = gate.startConversation()
        let duplicate = gate.startConversation()
        // Assert
        #expect(id != nil)
        #expect(duplicate == nil)
        #expect(gate.state == .captionsOnly)
        #expect(gate.currentWindow == nil)
    }

    /// Pause closes dispatch before the transport cancellation callback can reenter.
    @Test func pauseInvalidatesBeforeCancellation() throws {
        // Arrange
        var observed: TranslationGateState?
        var cancellationCount = 0
        weak var reference: TranslationGate?
        let gate = TranslationGate { _ in
            observed = reference?.state
            cancellationCount += 1
        }
        reference = gate
        let session = try #require(gate.startConversation())
        gate.enableASL(at: .zero)
        let window = try #require(gate.currentWindow)
        let utterance = FinalizedUtterance(sessionID: session, sequence: 1, text: "Synthetic", eligibility: .eligible(windowID: window.id))
        var token: SubmissionToken?
        #expect(gate.dispatch(utterance) { token = $0 })
        // Act
        gate.pauseASL()
        let late = gate.complete(try #require(token))
        let retry = gate.dispatch(utterance) { _ in Issue.record("Paused request started") }
        // Assert
        #expect(observed == .paused)
        #expect(cancellationCount == 1)
        #expect(late == false)
        #expect(retry == false)
        #expect(gate.sessionID == session)
    }

    /// A new resume window cannot replay prior or paused utterances.
    @Test func resumeRejectsOldEligibility() throws {
        // Arrange
        let gate = TranslationGate(cancelSubmission: { _ in })
        let session = try #require(gate.startConversation())
        gate.enableASL(at: .zero)
        let old = try #require(gate.currentWindow)
        let utterance = FinalizedUtterance(sessionID: session, sequence: 1, text: "Synthetic", eligibility: .eligible(windowID: old.id))
        // Act
        gate.pauseASL()
        gate.enableASL(at: .zero)
        let accepted = gate.dispatch(utterance) { _ in Issue.record("Old text replayed") }
        // Assert
        #expect(gate.currentWindow?.id != old.id)
        #expect(accepted == false)
    }

    /// Completion releases capacity once, while sequence identity prevents resubmission.
    @Test func completionAndDuplicateSubmission() throws {
        // Arrange
        let gate = TranslationGate(cancelSubmission: { _ in })
        let session = try #require(gate.startConversation())
        gate.enableASL(at: .zero)
        let window = try #require(gate.currentWindow)
        let utterance = FinalizedUtterance(sessionID: session, sequence: 1, text: "Synthetic", eligibility: .eligible(windowID: window.id))
        var token: SubmissionToken?
        gate.dispatch(utterance) { token = $0 }
        // Act
        let submitted = try #require(token)
        let first = gate.complete(submitted)
        let duplicate = gate.complete(submitted)
        let resend = gate.dispatch(utterance) { _ in Issue.record("Duplicate dispatched") }
        // Assert
        #expect(first)
        #expect(duplicate == false)
        #expect(resend == false)
    }

    /// End/interruption cannot be reversed by resume or a late completion.
    @Test(arguments: [true, false])
    func terminationRequiresFreshStart(interrupted: Bool) throws {
        // Arrange
        var cancelled = 0
        let gate = TranslationGate { _ in cancelled += 1 }
        let session = try #require(gate.startConversation())
        gate.enableASL(at: .zero)
        let window = try #require(gate.currentWindow)
        let utterance = FinalizedUtterance(sessionID: session, sequence: 1, text: "Synthetic", eligibility: .eligible(windowID: window.id))
        var token: SubmissionToken?
        gate.dispatch(utterance) { token = $0 }
        // Act
        if interrupted { gate.interrupt() } else { gate.endConversation() }
        let resumed = gate.enableASL(at: .seconds(1))
        let acceptedLate = gate.complete(try #require(token))
        let newSession = gate.startConversation()
        // Assert
        #expect(resumed == false)
        #expect(acceptedLate == false)
        #expect(cancelled == 1)
        #expect(newSession != session)
        #expect(gate.state == .captionsOnly)
    }
    /// A completion from before pause cannot consume a newer request's capacity.
    @Test func lateCompletionAfterResume() throws {
        // Arrange
        let gate = TranslationGate(cancelSubmission: { _ in })
        let session = try #require(gate.startConversation())
        gate.enableASL(at: .zero)
        let oldWindow = try #require(gate.currentWindow)
        var oldToken: SubmissionToken?
        gate.dispatch(FinalizedUtterance(sessionID: session, sequence: 1, text: "Old", eligibility: .eligible(windowID: oldWindow.id))) { oldToken = $0 }
        gate.pauseASL()
        gate.enableASL(at: .seconds(2))
        let newWindow = try #require(gate.currentWindow)
        var newToken: SubmissionToken?
        gate.dispatch(FinalizedUtterance(sessionID: session, sequence: 2, text: "New", eligibility: .eligible(windowID: newWindow.id))) { newToken = $0 }
        // Act
        let oldAccepted = gate.complete(try #require(oldToken))
        let newAccepted = gate.complete(try #require(newToken))
        // Assert
        #expect(oldAccepted == false)
        #expect(newAccepted)
    }

    /// Excluded captions cannot be submitted even while ASL is enabled.
    @Test(arguments: [UtteranceExclusion.disabled, .crossedBoundary, .invalidTiming, .empty, .tooLong, .tooSlow])
    func excludedCaption(reason: UtteranceExclusion) throws {
        // Arrange
        let gate = TranslationGate(cancelSubmission: { _ in })
        let session = try #require(gate.startConversation())
        gate.enableASL(at: .zero)
        let utterance = FinalizedUtterance(sessionID: session, sequence: 1, text: "Synthetic", eligibility: .excluded(reason))
        // Act
        let accepted = gate.dispatch(utterance) { _ in Issue.record("Excluded caption dispatched") }
        // Assert
        #expect(accepted == false)
    }

    /// Foreign conversation callbacks neither dispatch nor advance the current sequence.
    @Test func foreignConversationIsRejected() throws {
        // Arrange
        let gate = TranslationGate(cancelSubmission: { _ in })
        let session = try #require(gate.startConversation())
        gate.enableASL(at: .zero)
        let window = try #require(gate.currentWindow)
        // Act
        let foreign = gate.dispatch(FinalizedUtterance(sessionID: UUID(), sequence: 99, text: "Foreign", eligibility: .eligible(windowID: window.id))) { _ in Issue.record("Foreign dispatched") }
        let current = gate.dispatch(FinalizedUtterance(sessionID: session, sequence: 1, text: "Current", eligibility: .eligible(windowID: window.id))) { _ in }
        // Assert
        #expect(foreign == false)
        #expect(current)
    }
}
