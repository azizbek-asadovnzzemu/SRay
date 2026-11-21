#if DEBUG
import ConversationCore
import SwiftUI

/// Explains why a retained caption has no matching pose in the local demo.
struct ASLFixtureOmissionView: View {
    private let title: LocalizedStringKey

    init(reason: TranslationOmission.Reason) {
        title = switch reason {
        case .capacity: "Sample queue full"
        case .expired: "Sample expired"
        case .requestFailed: "Sample unavailable"
        case .cancelled: "Sample cancelled"
        }
    }

    init(limit: CaptionTranslationLimit) {
        title = switch limit {
        case .textLength: "Sample exceeds the text limit"
        case .speechDuration: "Sample exceeds the speech duration limit"
        }
    }

    var body: some View {
        Label(title, systemImage: "exclamationmark.circle")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .accessibilityIdentifier("asl.demo.omission")
    }
}
#endif
