import SwiftUI

/// Explains the app's current caption handling and the planned Sign MT data flow.
struct ASLPrivacyView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("ASL translation is unavailable in this build.")
                    section("English captions") {
                        Text("English captions are processed on this device. Ending a conversation clears its captions.")
                    }
                    section("Online ASL translation") {
                        Text("If ASL translation becomes available, turning it on for a conversation will send new, finalized English captions to Sign MT. Provider access and text retention are still under review.")
                            .accessibilityIdentifier("asl.privacy.provider")
                    }
                    section("Pausing ASL") {
                        Text("Pausing stops new requests. Sign MT may already have received text from earlier requests.")
                    }
                }
                .frame(maxWidth: 480, alignment: .leading)
                .frame(maxWidth: .infinity)
                .padding()
            }
            .navigationTitle("ASL privacy")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", role: .cancel) { dismiss() }
                        .keyboardShortcut(.cancelAction)
                        .accessibilityIdentifier("asl.privacy.close")
                }
            }
        }
    }

    private func section<Content: View>(
        _ title: LocalizedStringKey, @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            content()
        }
    }
}
