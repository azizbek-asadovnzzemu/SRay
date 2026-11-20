import SRayUI
import SwiftUI

/// The native app composition root shared by iPhone, iPad and Vision Pro.
@main
struct SRayApp: App {
    @Environment(\.scenePhase) private var appPhase
    @State private var captions = CaptionSession.makeOnDevice()

    var body: some Scene {
        WindowGroup(id: ConversationView.sceneID) {
            ConversationView(session: captions)
        }
        #if os(visionOS)
        .defaultSize(width: 700, height: 480)
        .windowResizability(.contentMinSize)
        #endif
        .onChange(of: appPhase) { _, phase in
            if phase == .background { captions.interrupt() }
        }
    }
}
