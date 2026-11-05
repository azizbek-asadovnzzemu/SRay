import SRayUI
import SwiftUI

/// The native app composition root shared by iPhone, iPad and Vision Pro.
@main
struct SRayApp: App {
    /// The app's window, with conversation functionality explicitly unavailable.
    var body: some Scene {
        WindowGroup {
            ConversationView(availability: .unavailable)
        }
    }
}
