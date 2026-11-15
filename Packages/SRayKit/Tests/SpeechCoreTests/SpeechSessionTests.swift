import Testing
@testable import SpeechCore

/// Exercises lifecycle races using explicit signals rather than timing assumptions.
@MainActor
struct SpeechSessionTests {
    /// Stop during the permission dialog prevents a later grant from starting capture.
    @Test func stopDuringAuthorization() async {
        // Arrange
        let backend = ControlledSpeechBackend()
        let session = SpeechSession(backend: backend)
        var requests = backend.authorizationRequests.makeAsyncIterator()
        let task = Task { await session.run() }
        await requests.next()
        // Act
        session.stop()
        backend.resolveAuthorization(true)
        await task.value
        // Assert
        #expect(backend.startCount == 0)
        #expect(backend.stopCount == 1)
        #expect(session.state == .idle)
        #expect(session.latestEvent == nil)
    }

    /// A second window cannot acquire another microphone while authorization is pending.
    @Test func duplicateStartIsIgnored() async {
        // Arrange
        let backend = ControlledSpeechBackend()
        let session = SpeechSession(backend: backend)
        var requests = backend.authorizationRequests.makeAsyncIterator()
        let task = Task { await session.run() }
        await requests.next()
        // Act
        await session.run()
        backend.resolveAuthorization(false)
        await task.value
        // Assert
        #expect(backend.startCount == 0)
        #expect(session.state == .failed(.permissionDenied))
        #expect(backend.stopCount == 1)
    }

    /// Unsupported on-device recognition does not prompt or fall back to remote capture.
    @Test func unavailableRecognition() async {
        // Arrange
        let backend = ControlledSpeechBackend()
        backend.supportsOnDeviceRecognition = false
        let session = SpeechSession(backend: backend)
        // Act
        await session.run()
        // Assert
        #expect(session.state == .failed(.unavailable))
        #expect(backend.startCount == 0)
    }

    /// Stream completion and failure both release the backend exactly once.
    @Test(arguments: [nil, SpeechFailure.recognitionFailed, .overloaded])
    func streamTermination(failure: SpeechFailure?) async {
        // Arrange
        let backend = ControlledSpeechBackend()
        let session = SpeechSession(backend: backend)
        var requests = backend.authorizationRequests.makeAsyncIterator()
        var starts = backend.recognitionStarts.makeAsyncIterator()
        let task = Task { await session.run() }
        await requests.next()
        backend.resolveAuthorization(true)
        await starts.next()
        // Act
        backend.finish(throwing: failure)
        await task.value
        // Assert
        #expect(backend.startCount == 1)
        #expect(backend.stopCount == 1)
        #expect(session.state == failure.map(SpeechSessionState.failed) ?? .idle)
        #expect(session.latestEvent == nil)
    }

    /// A stopped authorization callback cannot overwrite a restarted session.
    @Test func stalePermissionCannotReviveOldSession() async {
        // Arrange
        let backend = ControlledSpeechBackend()
        let session = SpeechSession(backend: backend)
        var requests = backend.authorizationRequests.makeAsyncIterator()
        let old = Task { await session.run() }
        await requests.next()
        session.stop()
        let current = Task { await session.run() }
        await requests.next()
        // Act
        backend.resolveAuthorization(true)
        await old.value
        // Assert
        #expect(session.state == .authorizing)
        #expect(backend.startCount == 0)
        // Clean up the current pending request.
        backend.resolveAuthorization(false)
        await current.value
        #expect(session.state == .failed(.permissionDenied))
    }

    /// Task cancellation during authorization cannot begin capture after a late grant.
    @Test func cancellationDuringAuthorization() async {
        // Arrange
        let backend = ControlledSpeechBackend()
        let session = SpeechSession(backend: backend)
        var requests = backend.authorizationRequests.makeAsyncIterator()
        let task = Task { await session.run() }
        await requests.next()
        // Act
        task.cancel()
        backend.resolveAuthorization(true)
        await task.value
        // Assert
        #expect(session.state == .idle)
        #expect(backend.startCount == 0)
        #expect(backend.stopCount == 1)
    }

    /// Partial setup failure still invokes the backend's idempotent cleanup.
    @Test func setupFailureReleasesResources() async {
        // Arrange
        let backend = ControlledSpeechBackend()
        backend.startFailure = .recognitionFailed
        let session = SpeechSession(backend: backend)
        var requests = backend.authorizationRequests.makeAsyncIterator()
        let task = Task { await session.run() }
        await requests.next()
        // Act
        backend.resolveAuthorization(true)
        await task.value
        // Assert
        #expect(session.state == .failed(.recognitionFailed))
        #expect(backend.stopCount == 1)
    }
    /// Final text reaches the consumer before ephemeral session storage is cleared.
    @Test func finalEventIsDeliveredBeforeCleanup() async {
        // Arrange
        let backend = ControlledSpeechBackend()
        let session = SpeechSession(backend: backend)
        var requests = backend.authorizationRequests.makeAsyncIterator()
        var starts = backend.recognitionStarts.makeAsyncIterator()
        var received: [SpeechEvent] = []
        let task = Task { await session.run { received.append($0) } }
        await requests.next()
        backend.resolveAuthorization(true)
        await starts.next()
        // Act
        backend.yield(SpeechEvent(text: "Synthetic greeting", isFinal: true))
        backend.finish()
        await task.value
        // Assert
        #expect(received == [SpeechEvent(text: "Synthetic greeting", isFinal: true)])
        #expect(session.latestEvent == nil)
        #expect(session.state == .idle)
    }

    /// A finished recognizer can be explicitly restarted without retaining resources.
    @Test func explicitRestartAfterCompletion() async {
        // Arrange
        let backend = ControlledSpeechBackend()
        let session = SpeechSession(backend: backend)
        var requests = backend.authorizationRequests.makeAsyncIterator()
        var starts = backend.recognitionStarts.makeAsyncIterator()
        // Act
        for _ in 0..<2 {
            let task = Task { await session.run() }
            await requests.next()
            backend.resolveAuthorization(true)
            await starts.next()
            backend.finish()
            await task.value
        }
        // Assert
        #expect(backend.startCount == 2)
        #expect(backend.stopCount == 2)
        #expect(session.state == .idle)
    }
    /// Cancelling a task actively reading recognition releases capture.
    @Test func cancellationDuringRecognition() async {
        // Arrange
        let backend = ControlledSpeechBackend()
        let session = SpeechSession(backend: backend)
        var requests = backend.authorizationRequests.makeAsyncIterator()
        var starts = backend.recognitionStarts.makeAsyncIterator()
        let task = Task { await session.run() }
        await requests.next()
        backend.resolveAuthorization(true)
        await starts.next()
        // Act
        task.cancel()
        await task.value
        // Assert
        #expect(session.state == .idle)
        #expect(backend.stopCount == 1)
    }

    /// Buffered events from a stopped session cannot reach a restarted consumer.
    @Test func staleBufferedEventAfterRestart() async {
        // Arrange
        let backend = ControlledSpeechBackend()
        let session = SpeechSession(backend: backend)
        var requests = backend.authorizationRequests.makeAsyncIterator()
        var starts = backend.recognitionStarts.makeAsyncIterator()
        var received: [SpeechEvent] = []
        let old = Task { await session.run { received.append($0) } }
        await requests.next()
        backend.resolveAuthorization(true)
        await starts.next()
        // Act: no suspension between buffering and invalidation.
        backend.yield(SpeechEvent(text: "Old synthetic text", isFinal: true))
        session.stop()
        let current = Task { await session.run { received.append($0) } }
        await requests.next()
        await old.value
        backend.resolveAuthorization(true)
        await starts.next()
        backend.yield(SpeechEvent(text: "Current synthetic text", isFinal: true))
        backend.finish()
        await current.value
        // Assert
        #expect(received == [SpeechEvent(text: "Current synthetic text", isFinal: true)])
        #expect(backend.stopCount == 2)
    }

    /// Overflow of an actual bounded test stream reports a visible failure.
    @Test func boundedStreamOverflow() async {
        // Arrange
        let backend = ControlledSpeechBackend()
        let session = SpeechSession(backend: backend)
        var requests = backend.authorizationRequests.makeAsyncIterator()
        var starts = backend.recognitionStarts.makeAsyncIterator()
        let task = Task { await session.run() }
        await requests.next()
        backend.resolveAuthorization(true)
        await starts.next()
        // Act: fill without yielding to the consumer.
        for _ in 0..<10 { backend.yield(SpeechEvent(text: "Synthetic", isFinal: false)) }
        backend.finish()
        await task.value
        // Assert
        #expect(session.state == .failed(.overloaded))
        #expect(backend.stopCount == 1)
    }
}
