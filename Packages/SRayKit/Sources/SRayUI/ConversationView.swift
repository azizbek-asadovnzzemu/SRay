import ConversationCore
import SwiftUI

/// The shared native entry screen for a conversation.
public struct ConversationView: View {
    /// The capability supplied by the app composition root.
    private let availability: ConversationAvailability

    /// Creates a screen for the explicitly supplied conversation capability.
    public init(availability: ConversationAvailability) {
        self.availability = availability
    }

    /// A readable empty state until the conversation pipeline is integrated.
    public var body: some View {
        NavigationStack {
            switch availability {
            case .unavailable:
                ContentUnavailableView(
                    "Conversations aren’t available yet",
                    systemImage: "captions.bubble",
                    description: Text("Live captions and ASL conversations are coming to SRay.")
                )
                .navigationTitle("SRay")
            }
        }
    }
}
