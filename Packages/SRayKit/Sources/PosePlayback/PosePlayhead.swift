import Foundation

/// Explicitly controlled playback driven by session-relative monotonic time.
struct PosePlayhead: Equatable {
    private var heldSeconds: Double = 0
    private var beganAt: Duration?

    /// Whether elapsed time is accumulating.
    var isPlaying: Bool { beganAt != nil }

    /// Resumes from the held position.
    mutating func play(at instant: Duration) {
        guard beganAt == nil else { return }
        beganAt = instant
    }

    /// Keeps the last visible position without continuing to advance.
    mutating func pause(at instant: Duration, duration: Double) {
        heldSeconds = elapsed(at: instant, duration: duration)
        beganAt = nil
    }

    /// Starts the same clip from the first frame.
    mutating func replay(at instant: Duration) {
        heldSeconds = 0
        beganAt = instant
    }

    /// Returns seconds into the clip, clamped to its actual duration.
    func elapsed(at instant: Duration, duration: Double) -> Double {
        guard let beganAt else { return min(duration, heldSeconds) }
        let delta = max(.zero, instant - beganAt).components
        let seconds = Double(delta.seconds) + Double(delta.attoseconds) / 1e18
        return min(duration, heldSeconds + seconds)
    }

    /// Chooses a discrete source frame and holds the final frame at the end.
    func frame(at instant: Duration, framesPerSecond: Double, frameCount: Int) -> Int {
        let duration = Double(frameCount) / framesPerSecond
        return min(frameCount - 1, Int(elapsed(at: instant, duration: duration) * framesPerSecond))
    }
}
