#if os(iOS) || os(visionOS)
import ConversationCore
import SpeechPlatform

extension CaptionSession {
    /// Creates the app's shared session using Apple's on-device capture backend.
    @MainActor public static func makeOnDevice() -> CaptionSession {
        CaptionSession(backend: AppleSpeechBackend())
    }
}
#endif
