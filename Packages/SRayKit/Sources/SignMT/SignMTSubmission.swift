import Foundation
import os
import PoseCore

/// A started request. Consume its single result once, or cancel it from the transmission gate.
final class SignMTSubmission: Sendable {
    private let poses: AsyncThrowingStream<ReceivedPose, any Error>
    private let cancelTask: @Sendable () -> Void
    private let cancelled = OSAllocatedUnfairLock(initialState: false)

    /// Creates a result handle for one transport operation.
    init(poses: AsyncThrowingStream<ReceivedPose, any Error>, cancelTask: @escaping @Sendable () -> Void) {
        self.poses = poses
        self.cancelTask = cancelTask
    }

    deinit { cancel() }

    /// Requests cancellation and prevents the result consumer from returning a buffered pose.
    func cancel() {
        let wasCancelled = cancelled.withLock { value in
            let previous = value
            value = true
            return previous
        }
        if !wasCancelled { cancelTask() }
    }

    /// Waits for the response and cancels the underlying request if the waiting task is cancelled.
    func response() async throws -> ReceivedPose {
        try await withTaskCancellationHandler {
            try checkCancellation()
            var iterator = poses.makeAsyncIterator()
            do {
                let pose = try await iterator.next()
                try checkCancellation()
                guard let pose else { throw SignMTFailure.unavailable }
                return pose
            } catch {
                try checkCancellation()
                throw error
            }
        } onCancel: {
            cancel()
        }
    }

    /// Receives and structurally validates one pose for the experimental v0.2 decoder.
    /// The caller must still validate its submission identity before displaying the result.
    func decodedPose() async throws -> PoseSequence {
        let received = try await response()
        let pose: PoseSequence
        do {
            pose = try PoseDecoder.decode(received.bytes)
        } catch let failure as PoseDecodingError {
            try checkCancellation()
            throw SignMTFailure.invalidPose(failure)
        } catch {
            try checkCancellation()
            throw SignMTFailure.invalidResponse
        }
        try checkCancellation()
        return pose
    }

    private func checkCancellation() throws {
        try Task.checkCancellation()
        if cancelled.withLock({ $0 }) { throw CancellationError() }
    }
}
