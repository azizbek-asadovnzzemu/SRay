/// A permission state reported by a platform adapter without requesting access.
public enum SpeechPermission: Sendable {
    /// Access has not been requested.
    case notDetermined
    /// The user permitted recognition.
    case authorized
    /// Access was denied or restricted.
    case denied
}

/// A preflight outcome, not proof that offline recognition works on a device.
public enum SpeechReadiness: Equatable, Sendable {
    /// No recognizer exists for the requested locale.
    case unsupportedLocale
    /// The recognizer does not advertise on-device recognition.
    case onDeviceRecognitionUnavailable
    /// An in-context permission request is needed before testing.
    case permissionRequired
    /// Permission must be restored before testing.
    case permissionDenied
    /// Capabilities permit a physical offline test; installed assets remain unverified.
    case readyForOfflineTest
}

/// Records platform capabilities without capturing audio or contacting a service.
public struct SpeechCapabilities: Sendable {
    /// Whether the platform creates a recognizer for the chosen locale.
    public let hasRecognizer: Bool
    /// Whether the recognizer advertises on-device recognition support.
    public let supportsOnDeviceRecognition: Bool
    /// The recognition permission state at the time of inspection.
    public let permission: SpeechPermission

    /// Creates a capability snapshot for preflight evaluation.
    public init(hasRecognizer: Bool, supportsOnDeviceRecognition: Bool, permission: SpeechPermission) {
        self.hasRecognizer = hasRecognizer
        self.supportsOnDeviceRecognition = supportsOnDeviceRecognition
        self.permission = permission
    }

    /// The next step before a physical offline test, without cloud fallback.
    public var readiness: SpeechReadiness {
        guard hasRecognizer else { return .unsupportedLocale }
        guard supportsOnDeviceRecognition else { return .onDeviceRecognitionUnavailable }
        switch permission {
        case .notDetermined: return .permissionRequired
        case .denied: return .permissionDenied
        case .authorized: return .readyForOfflineTest
        }
    }
}
