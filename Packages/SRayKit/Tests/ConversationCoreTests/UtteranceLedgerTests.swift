import Foundation
import Testing
@testable import ConversationCore

/// Verifies whole-utterance bounds and privacy without a speech or network service.
struct UtteranceLedgerTests {
    /// Finalization preserves corrected text and suppresses duplicate callbacks.
    @Test func finalizesOnceWithCompleteCorrection() throws {
        // Arrange
        var ledger = UtteranceLedger(sessionID: UUID())
        let window = TranslationWindow(id: UUID(), openedAt: .zero)
        let began = ledger.begin(sequence: 1, startedAt: .seconds(1), window: window)
        #expect(began)
        #expect(ledger.acceptsPartial(sequence: 1))
        // Act
        let result = ledger.finalize(sequence: 1, text: "Do not turn left", endedAt: .seconds(3), window: window)
        let final = try #require(result)
        let duplicate = ledger.finalize(sequence: 1, text: "Turn left", endedAt: .seconds(3), window: window)
        // Assert
        #expect(final.text == "Do not turn left")
        #expect(final.eligibility == .eligible(windowID: window.id))
        #expect(duplicate == nil)
        #expect(ledger.acceptsPartial(sequence: 1) == false)
    }

    /// Bounds count grapheme clusters and never truncate an excluded caption.
    @Test(arguments: [280, 281])
    func graphemeBound(count: Int) throws {
        // Arrange
        var ledger = UtteranceLedger(sessionID: UUID())
        let window = TranslationWindow(id: UUID(), openedAt: .zero)
        let text = String(repeating: "👨‍👩‍👧‍👦", count: count)
        ledger.begin(sequence: 1, startedAt: .zero, window: window)
        // Act
        let result = ledger.finalize(sequence: 1, text: text, endedAt: .seconds(1), window: window)
        let final = try #require(result)
        // Assert
        #expect(final.text == text)
        #expect(final.eligibility == (count == 280 ? .eligible(windowID: window.id) : .excluded(.tooLong)))
    }

    /// Fifteen seconds is accepted; longer speech remains a caption only.
    @Test(arguments: [Duration.seconds(15), .milliseconds(15_001)])
    func durationBound(duration: Duration) throws {
        // Arrange
        var ledger = UtteranceLedger(sessionID: UUID())
        let window = TranslationWindow(id: UUID(), openedAt: .zero)
        ledger.begin(sequence: 1, startedAt: .zero, window: window)
        // Act
        let result = ledger.finalize(sequence: 1, text: "Synthetic", endedAt: duration, window: window)
        let final = try #require(result)
        // Assert
        #expect(final.eligibility == (duration == .seconds(15) ? .eligible(windowID: window.id) : .excluded(.tooSlow)))
    }

    /// Paused or pre-enable speech cannot be made eligible by a later resume.
    @Test(arguments: [true, false])
    func changedWindowExcludesWholeUtterance(wasEnabled: Bool) throws {
        // Arrange
        var ledger = UtteranceLedger(sessionID: UUID())
        let old = TranslationWindow(id: UUID(), openedAt: .zero)
        ledger.begin(sequence: 1, startedAt: .seconds(1), window: wasEnabled ? old : nil)
        let resumed = TranslationWindow(id: UUID(), openedAt: .seconds(1))
        // Act
        let result = ledger.finalize(sequence: 1, text: "Synthetic", endedAt: .seconds(3), window: resumed)
        let final = try #require(result)
        // Assert
        #expect(final.eligibility == .excluded(.crossedBoundary))
    }

    /// Unknown, negative and reversed source timestamps never qualify for transmission.
    @Test(arguments: [(Optional<Duration>.none, Optional<Duration>.some(.seconds(2))),
                      (.some(.seconds(-1)), .some(.seconds(2))),
                      (.some(.seconds(3)), .some(.seconds(2)))])
    func invalidTiming(start: Duration?, end: Duration?) throws {
        // Arrange
        var ledger = UtteranceLedger(sessionID: UUID())
        let window = TranslationWindow(id: UUID(), openedAt: .zero)
        ledger.begin(sequence: 1, startedAt: start, window: window)
        // Act
        let result = ledger.finalize(sequence: 1, text: "Synthetic", endedAt: end, window: window)
        let final = try #require(result)
        // Assert
        #expect(final.eligibility == .excluded(.invalidTiming))
    }

    /// Restart overlap cannot replace a pending utterance or resurrect interrupted IDs.
    @Test func restartOverlap() {
        // Arrange
        var ledger = UtteranceLedger(sessionID: UUID())
        ledger.begin(sequence: 1, startedAt: .zero, window: nil)
        // Act
        let replacement = ledger.begin(sequence: 2, startedAt: .seconds(1), window: nil)
        let interrupted = ledger.interrupt()
        let reused = ledger.begin(sequence: 1, startedAt: .seconds(1), window: nil)
        let fresh = ledger.begin(sequence: 2, startedAt: .seconds(1), window: nil)
        // Assert
        #expect(replacement == false)
        #expect(interrupted == 1)
        #expect(reused == false)
        #expect(fresh)
        let late = ledger.finalize(sequence: 1, text: "Late", endedAt: .seconds(2), window: nil)
        #expect(late == nil)
    }
    /// Pausing before a final callback keeps the caption local.
    @Test func pausedFinalStaysLocal() throws {
        // Arrange
        var ledger = UtteranceLedger(sessionID: UUID())
        let window = TranslationWindow(id: UUID(), openedAt: .zero)
        ledger.begin(sequence: 1, startedAt: .zero, window: window)
        // Act
        let result = ledger.finalize(sequence: 1, text: "Synthetic", endedAt: .seconds(1), window: nil)
        let final = try #require(result)
        // Assert
        #expect(final.eligibility == .excluded(.disabled))
        #expect(final.text == "Synthetic")
    }

    /// A delayed start callback cannot relabel speech that began before enable.
    @Test func sourceStartBeforeEnable() throws {
        // Arrange
        var ledger = UtteranceLedger(sessionID: UUID())
        let window = TranslationWindow(id: UUID(), openedAt: .seconds(2))
        ledger.begin(sequence: 1, startedAt: .seconds(1), window: window)
        // Act
        let result = ledger.finalize(sequence: 1, text: "Synthetic", endedAt: .seconds(3), window: window)
        let final = try #require(result)
        // Assert
        #expect(final.eligibility == .excluded(.crossedBoundary))
    }

    /// Empty recognizer results are never eligible for a service request.
    @Test(arguments: ["", " \n\t"])
    func emptyText(text: String) throws {
        // Arrange
        var ledger = UtteranceLedger(sessionID: UUID())
        let window = TranslationWindow(id: UUID(), openedAt: .zero)
        ledger.begin(sequence: 1, startedAt: .zero, window: window)
        // Act
        let result = ledger.finalize(sequence: 1, text: text, endedAt: .seconds(1), window: window)
        let final = try #require(result)
        // Assert
        #expect(final.eligibility == .excluded(.empty))
    }
}
