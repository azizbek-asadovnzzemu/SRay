import Foundation
import SpeechCore
import Testing
@testable import ConversationCore

/// Verifies how the app-owned model coordinates the capture and memory modules.
@MainActor
struct CaptionSessionTests {
    /// A final caption replaces its partial, survives request completion, and clears on end.
    @Test func readsFinalCaptionUntilEnd() async throws {
        // Arrange
        let backend = ControlledSpeechBackend()
        let session = CaptionSession(backend: backend)
        var permissions = backend.authorizationRequests.makeAsyncIterator()
        var starts = backend.recognitionStarts.makeAsyncIterator()

        // Act
        session.start()
        await permissions.next()
        backend.resolveAuthorization(true)
        await starts.next()
        backend.yield(SpeechEvent(text: "Turn", isFinal: false))
        backend.yield(SpeechEvent(text: "Do not turn", isFinal: true))
        backend.finish()
        await session.waitForCaptureToFinish()

        // Assert
        #expect(session.phase == .finished)
        let final = try #require(session.lines.first)
        #expect(session.lines.count == 1)
        #expect(final.text == "Do not turn")
        #expect(final.isFinal)
        session.end()
        #expect(session.phase == .ready)
        #expect(session.lines.isEmpty)
        #expect(session.canEnd == false)
    }

    /// A second start shares the capture owner and background invalidates buffered text.
    @Test func interruptDiscardsPendingCaption() async {
        // Arrange
        let backend = ControlledSpeechBackend()
        let session = CaptionSession(backend: backend)
        var permissions = backend.authorizationRequests.makeAsyncIterator()
        var starts = backend.recognitionStarts.makeAsyncIterator()
        session.start()
        await permissions.next()
        backend.resolveAuthorization(true)
        await starts.next()

        // Act
        session.start()
        backend.yield(SpeechEvent(text: "Synthetic caption", isFinal: true))
        session.interrupt()
        await session.waitForCaptureToFinish()

        // Assert
        #expect(backend.startCount == 1)
        #expect(backend.stopCount == 1)
        #expect(session.phase == .interrupted)
        #expect(session.lines.isEmpty)
    }

    /// Denied authorization presents a recoverable state without opening capture.
    @Test func denialKeepsMicrophoneClosed() async {
        // Arrange
        let backend = ControlledSpeechBackend()
        let session = CaptionSession(backend: backend)
        var permissions = backend.authorizationRequests.makeAsyncIterator()

        // Act
        session.start()
        await permissions.next()
        backend.resolveAuthorization(false)
        await session.waitForCaptureToFinish()

        // Assert
        #expect(session.phase == .failed(.permissionDenied))
        #expect(backend.startCount == 0)
        #expect(session.lines.isEmpty)
    }

    /// A large recognizer result stops capture without retaining the rejected text.
    @Test func oversizedSnapshotStopsCapture() async {
        // Arrange
        let backend = ControlledSpeechBackend()
        let session = CaptionSession(backend: backend)
        var permissions = backend.authorizationRequests.makeAsyncIterator()
        var starts = backend.recognitionStarts.makeAsyncIterator()
        session.start()
        await permissions.next()
        backend.resolveAuthorization(true)
        await starts.next()

        // Act
        let large = String(repeating: "x", count: CaptionMemory.maximumBytesPerLine + 1)
        backend.yield(SpeechEvent(text: large, isFinal: true))
        await session.waitForCaptureToFinish()

        // Assert
        #expect(session.phase == .oversized)
        #expect(session.lines.isEmpty)
        #expect(backend.stopCount == 1)
    }

    /// A finished conversation still loses expired text while no speech is coming in.
    @Test func expiresWhileWaitingForReader() async {
        // Arrange
        let backend = ControlledSpeechBackend()
        let origin = ContinuousClock.now
        var time = origin
        let session = CaptionSession(backend: backend, now: { time })
        var permissions = backend.authorizationRequests.makeAsyncIterator()
        var starts = backend.recognitionStarts.makeAsyncIterator()
        session.start()
        await permissions.next()
        backend.resolveAuthorization(true)
        await starts.next()
        backend.yield(SpeechEvent(text: "Synthetic caption", isFinal: true))
        backend.finish()
        await session.waitForCaptureToFinish()
        #expect(session.lines.count == 1)

        // Act
        time = origin.advanced(by: CaptionMemory.maximumAge)
        session.expireCaptions()

        // Assert
        #expect(session.lines.isEmpty)
        #expect(session.phase == .finished)
    }

    /// An audio interruption clears the transcript and requires an explicit new start.
    @Test func audioInterruptionRequiresNewStart() async {
        // Arrange
        let backend = ControlledSpeechBackend()
        let session = CaptionSession(backend: backend)
        var permissions = backend.authorizationRequests.makeAsyncIterator()
        var starts = backend.recognitionStarts.makeAsyncIterator()
        session.start()
        await permissions.next()
        backend.resolveAuthorization(true)
        await starts.next()
        backend.yield(SpeechEvent(text: "Synthetic", isFinal: true))
        backend.finish()
        await session.waitForCaptureToFinish()
        #expect(session.lines.count == 1)
        session.start()
        await permissions.next()
        backend.resolveAuthorization(true)
        await starts.next()

        // Act
        backend.finish(throwing: .interrupted)
        await session.waitForCaptureToFinish()

        // Assert
        #expect(session.phase == .interrupted)
        #expect(session.lines.isEmpty)
        #expect(session.canEnd == false)
        #expect(backend.startCount == 2)
        #expect(backend.stopCount == 2)
    }

    /// Closing either window preserves the shared capture until the last window closes.
    @Test func lastWindowStopsSharedCapture() async {
        // Arrange
        let backend = ControlledSpeechBackend()
        let session = CaptionSession(backend: backend)
        let first = UUID()
        let second = UUID()
        session.windowDidOpen(first)
        session.windowDidOpen(second)
        var permissions = backend.authorizationRequests.makeAsyncIterator()
        var starts = backend.recognitionStarts.makeAsyncIterator()
        session.start()
        await permissions.next()
        backend.resolveAuthorization(true)
        await starts.next()

        // Act and assert
        session.windowDidClose(first)
        session.windowDidClose(first)
        #expect(session.phase == .listening)
        #expect(backend.stopCount == 0)
        session.windowDidClose(second)
        #expect(session.phase == .interrupted)
        #expect(session.lines.isEmpty)
        #expect(backend.stopCount == 1)
    }
}
