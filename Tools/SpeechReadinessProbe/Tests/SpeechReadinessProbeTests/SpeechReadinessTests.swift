import Testing
@testable import SpeechReadinessProbe

/// Verifies preflight failure states independently of microphone and OS authorization.
@Suite struct SpeechReadinessTests {
    /// Missing locale support takes precedence over a permission request.
    @Test func unsupportedLocaleDoesNotRequestPermission() {
        // Arrange
        let snapshot = SpeechCapabilities(hasRecognizer: false, supportsOnDeviceRecognition: false, permission: .notDetermined)
        // Act
        let readiness = snapshot.readiness
        // Assert
        #expect(readiness == .unsupportedLocale)
    }

    /// Online-only recognition cannot qualify as an offline candidate.
    @Test func unsupportedOnDeviceRecognitionDoesNotFallBack() {
        // Arrange
        let snapshot = SpeechCapabilities(hasRecognizer: true, supportsOnDeviceRecognition: false, permission: .authorized)
        // Act
        let readiness = snapshot.readiness
        // Assert
        #expect(readiness == .onDeviceRecognitionUnavailable)
    }

    /// Each permission state maps to an explicit next step.
    @Test(arguments: [
        (SpeechPermission.notDetermined, SpeechReadiness.permissionRequired),
        (.denied, .permissionDenied),
        (.authorized, .readyForOfflineTest)
    ])
    func permissionDeterminesNextStep(permission: SpeechPermission, expected: SpeechReadiness) {
        // Arrange
        let snapshot = SpeechCapabilities(hasRecognizer: true, supportsOnDeviceRecognition: true, permission: permission)
        // Act
        let readiness = snapshot.readiness
        // Assert
        #expect(readiness == expected)
    }
}
