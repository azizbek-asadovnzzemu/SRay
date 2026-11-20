import SpeechCore

/// Visible state of the local captions experience.
public enum CaptionSessionPhase: Equatable, Sendable {
    /// A new conversation can start.
    case ready
    /// The device is preparing capture or awaiting permission.
    case preparing
    /// The microphone is active and recognition is running on the device.
    case listening
    /// Recognition finished. The reader can continue or end the conversation.
    case finished
    /// Capture was stopped when the app moved to the background.
    case interrupted
    /// A capture attempt failed with a content-free reason.
    case failed(SpeechFailure)
    /// The recognizer returned more text than one caption can hold.
    case oversized
}
