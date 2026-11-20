import SRayUI
import SwiftUI

/// The native app composition root shared by iPhone, iPad and Vision Pro.
@main
struct SRayApp: App {
    @Environment(\.scenePhase) private var appPhase
    @State private var captions = CaptionSession.makeOnDevice()

    var body: some Scene {
        WindowGroup {
            ConversationView(session: captions)
        }
        .onChange(of: appPhase) { _, phase in
            if phase == .background { captions.interrupt() }
        }
    }
}
