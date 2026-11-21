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
    private static let fixture: ASLFixtureConversation? = {
        switch ProcessInfo.processInfo.environment["SRAY_SYNTHETIC_ASL"] {
        case "1": ASLFixtureConversation()
        case "failure": ASLFixtureConversation(failsFirstRequest: true)
        case "rate-limited": ASLFixtureConversation(firstRequestRetryDelay: .seconds(10))
        case "over-limit": ASLFixtureConversation(usesOverLimitSample: true)
        case "audit":
            ASLFixtureConversation(onAuditCompletion: {
                SRayApp.auditLog.notice("Synthetic pose audit ready")
            })
        default: nil
        }
    }()
    private static let auditLog = Logger(subsystem: "com.azizbekasadov.sray.audit", category: "fixture")
    #endif

    var body: some Scene {
        WindowGroup(id: ConversationView.sceneID) {
            conversationView
                #if DEBUG
                .onAppear {
                    if Self.runsCaptionAudit || Self.fixture?.isRunningAudit == true { captions.start() }
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
    private var conversationView: ConversationView {
        #if DEBUG
        if let fixture = Self.fixture { return ConversationView(fixture: fixture) }
        #endif
        return ConversationView(session: captions)
    }

    @MainActor
    private static func makeCaptionSession() -> CaptionSession {
        #if DEBUG
        if let fixture { return fixture.captions }
        if ProcessInfo.processInfo.environment["SRAY_SYNTHETIC_CAPTIONS"] == "1" {
            return .makeSynthetic()
        }
        #endif
        return .makeOnDevice()
    }
}
