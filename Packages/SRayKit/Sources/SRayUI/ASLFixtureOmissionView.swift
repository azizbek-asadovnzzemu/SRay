#if DEBUG
import ConversationCore
import SwiftUI

/// Explains why a retained caption has no matching pose in the local demo.
struct ASLFixtureOmissionView: View {
    let reason: TranslationOmission.Reason

    var body: some View {
        Label(title, systemImage: "exclamationmark.circle")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .accessibilityIdentifier("asl.demo.omission")
    }

    private var title: LocalizedStringKey {
        switch reason {
        case .capacity: "Sample queue full"
        case .expired: "Sample expired"
        case .requestFailed: "Sample unavailable"
        case .cancelled: "Sample cancelled"
        }
    }
}
#endif
