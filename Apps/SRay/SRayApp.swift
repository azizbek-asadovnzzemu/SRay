import Foundation
import SRayUI
import SwiftUI
#if DEBUG
import OSLog
#endif

/// The native app composition root shared by iPhone, iPad and Vision Pro.
@main
struct SRayApp: App {
    @Environment(\.scenePhase) private var appPhase
    @State private var captions = Self.makeCaptionSession()
    #if DEBUG
    private static let runsCaptionAudit = ProcessInfo.processInfo.environment["SRAY_SYNTHETIC_CAPTIONS"] == "1"
        && ProcessInfo.processInfo.environment["SRAY_CAPTION_AUDIT"] == "1"
    private static let auditLog = Logger(subsystem: "com.azizbekasadov.sray.audit", category: "fixture")
    #endif

    var body: some Scene {
        WindowGroup(id: ConversationView.sceneID) {
            ConversationView(session: captions)
                #if DEBUG
                .onAppear {
                    if Self.runsCaptionAudit { captions.start() }
                }
                .onChange(of: captions.phase) { _, phase in
                    if Self.runsCaptionAudit, phase == .finished, captions.lines.last?.isFinal == true {
                        Self.auditLog.notice("Synthetic caption audit ready")
                    }
                }
                #endif
        }
        #if os(visionOS)
        .defaultSize(width: 700, height: 480)
        .windowResizability(.contentMinSize)
        #endif
        .onChange(of: appPhase) { _, phase in
            if phase == .background { captions.interrupt() }
        }
    }
    @MainActor
    private static func makeCaptionSession() -> CaptionSession {
        #if DEBUG
        if ProcessInfo.processInfo.environment["SRAY_SYNTHETIC_CAPTIONS"] == "1" {
            return .makeSynthetic()
        }
        #endif
        return .makeOnDevice()
    }
}
