import Foundation
import Testing
@testable import ConversationCore

/// Tests bounded content storage with an explicit monotonic clock.
struct CaptionMemoryTests {
    /// Partial corrections keep one identity and final text cannot be rewritten by late callbacks.
    @Test func partialSettlesIntoOneFinalRow() {
        // Arrange
        var memory = CaptionMemory()
        let id = UUID()
        memory.update(id: id, text: "Turn", isFinal: false, startedAt: .zero, now: .zero)
        // Act
        memory.update(id: id, text: "Do not turn", isFinal: true, startedAt: .zero, now: .seconds(1))
        let late = memory.update(id: id, text: "Turn", isFinal: false, startedAt: .zero, now: .seconds(2))
        let rows = memory.snapshot(at: .seconds(2))
        // Assert
        #expect(rows.count == 1)
        #expect(rows.first?.id == id)
        #expect(rows.first?.text == "Do not turn")
        #expect(rows.first?.isFinal == true)
        #expect(late == .ignored)
    }

    /// Row count is bounded across long conversations.
    @Test func retainsOnlyLatestTwoHundredRows() {
        // Arrange
        var memory = CaptionMemory()
        let oldest = UUID()
        memory.update(id: oldest, text: "Oldest", isFinal: true, startedAt: .zero, now: .zero)
        // Act
        for index in 1...200 {
            memory.update(id: UUID(), text: "Synthetic", isFinal: true, startedAt: .seconds(index), now: .seconds(index))
        }
        let rows = memory.snapshot(at: .seconds(200))
        // Assert
        #expect(rows.count == 200)
        #expect(rows.contains(where: { $0.id == oldest }) == false)
    }

    /// An update cannot extend a row's lifetime or revive expired text.
    @Test func expiresAtTenMinutesWithoutRevival() {
        // Arrange
        var memory = CaptionMemory()
        let id = UUID()
        memory.update(id: id, text: "Partial", isFinal: false, startedAt: .zero, now: .zero)
        memory.update(id: id, text: "Corrected", isFinal: false, startedAt: .zero, now: .seconds(599))
        // Act
        let before = memory.snapshot(at: .seconds(599))
        let expired = memory.snapshot(at: .seconds(600))
        let late = memory.update(id: id, text: "Late", isFinal: true, startedAt: .zero, now: .seconds(601))
        // Assert
        #expect(before.count == 1)
        #expect(expired.isEmpty)
        #expect(late == .ignored)
    }

    /// Oversized text is rejected as a whole, never silently truncated.
    @Test(arguments: [65_536, 65_537])
    func byteBound(count: Int) {
        // Arrange
        var memory = CaptionMemory()
        let text = String(repeating: "x", count: count)
        // Act
        let result = memory.update(id: UUID(), text: text, isFinal: true, startedAt: .zero, now: .zero)
        let rows = memory.snapshot(at: .zero)
        // Assert
        #expect(result == (count == 65_536 ? .stored : .rejectedOversize))
        #expect(rows.first?.text == (count == 65_536 ? text : nil))
    }

    /// Ending a conversation removes every synthetic sentinel from storage.
    @Test func clearRemovesAllContent() {
        // Arrange
        var memory = CaptionMemory()
        memory.update(id: UUID(), text: "PRIVATE_SYNTHETIC_SENTINEL", isFinal: true, startedAt: .zero, now: .zero)
        // Act
        memory.clear()
        let rows = memory.snapshot(at: .zero)
        // Assert
        #expect(rows.isEmpty)
    }
}
