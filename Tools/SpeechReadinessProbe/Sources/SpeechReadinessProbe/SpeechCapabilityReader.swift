import Foundation
import Speech

/// Inspects recognition capability without requesting access or recording audio.
public enum SpeechCapabilityReader {
    /// Returns a local capability snapshot for the requested locale.
    ///
    /// This does not download language assets or demonstrate offline recognition.
    /// - Parameter locale: The spoken language to inspect, such as English (United States).
    @MainActor public static func capabilities(for locale: Locale) -> SpeechCapabilities {
        let recognizer = SFSpeechRecognizer(locale: locale)
        let permission: SpeechPermission
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized: permission = .authorized
        case .notDetermined: permission = .notDetermined
        case .denied, .restricted: permission = .denied
        @unknown default: permission = .denied
        }
        return SpeechCapabilities(
            hasRecognizer: recognizer != nil,
            supportsOnDeviceRecognition: recognizer?.supportsOnDeviceRecognition ?? false,
            permission: permission
        )
    }
}
