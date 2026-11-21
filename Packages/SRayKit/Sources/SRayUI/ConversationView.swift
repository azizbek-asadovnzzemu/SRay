import ConversationCore
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// A window into the shared conversation, with independent reading controls.
public struct ConversationView: View {
    /// Identifier of the native scene that presents the shared caption session.
    public static let sceneID = "conversation"

    #if os(visionOS)
    @Environment(\.openWindow) private var openWindow
    @Environment(\.supportsMultipleWindows) private var supportsMultipleWindows
    #endif
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.openURL) private var openURL
    @State private var windowID = UUID()
    @State private var textSize: CaptionTextSize = .standard
    @State private var showsASLPrivacy = false
    @AccessibilityFocusState private var liveFocused: Bool
    private let session: CaptionSession
    #if DEBUG
    private let fixture: ASLFixtureConversation?
    #endif

    /// Creates a window for the app-owned caption session.
    public init(session: CaptionSession) {
        self.session = session
        #if DEBUG
        fixture = nil
        #endif
    }

    #if DEBUG
    /// Presents an isolated synthetic geometry demo around its shared caption session.
    public init(fixture: ASLFixtureConversation) {
        session = fixture.captions
        self.fixture = fixture
    }
    #endif

    public var body: some View {
        NavigationStack {
            GeometryReader { window in
                ScrollViewReader { proxy in
                    ScrollView {
                        conversationContent(windowWidth: window.size.width)
                            .padding()
                            .frame(maxWidth: .infinity)
                    }
                    .background {
                        if reduceTransparency { opaqueSurface }
                    }
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        if session.canEnd {
                            sessionControls {
                                proxy.scrollTo(ScrollTarget.live, anchor: .top)
                                liveFocused = true
                            }
                        } else {
                            primaryStartButton(dynamicTypeSize.isAccessibilitySize ? "Start Captions" : "Start Conversation")
                                .accessibilityIdentifier("caption.start")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background { controlSurface }
                        }
                    }
                }
            }
            .navigationTitle("SRay")
            #if os(iOS)
            .navigationBarTitleDisplayMode(dynamicTypeSize.isAccessibilitySize ? .inline : .automatic)
            #endif
            .toolbar {
                #if DEBUG
                if let fixture, scenePhase == .active, fixture.translation.presentation.state == .enabled {
                    #if os(macOS)
                    let placement = ToolbarItemPlacement.primaryAction
                    #else
                    let placement = ToolbarItemPlacement.topBarLeading
                    #endif
                    ToolbarItem(placement: placement) {
                        Button("Pause Demo", systemImage: "pause", action: fixture.translation.pause)
                            .labelStyle(.iconOnly)
                            .accessibilityIdentifier("asl.demo.pause")
                    }
                }
                #endif
                #if os(visionOS)
                if supportsMultipleWindows {
                    ToolbarItem(placement: .secondaryAction) {
                        Button("New Caption Window", systemImage: "macwindow.badge.plus") {
                            openWindow(id: Self.sceneID)
                        }
                    }
                }
                #endif
                ToolbarItem(placement: .primaryAction) {
                    Menu("Caption Text Size", systemImage: "textformat.size") {
                        Picker("Caption Text Size", selection: $textSize) {
                            Text("Standard").tag(CaptionTextSize.standard)
                            Text("Large").tag(CaptionTextSize.large)
                            Text("Extra Large").tag(CaptionTextSize.extraLarge)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showsASLPrivacy) { ASLPrivacyView() }
        .onAppear { session.windowDidOpen(windowID) }
        .onDisappear { session.windowDidClose(windowID) }
    }

    /// Reflows the same content and scroll view as the window changes size.
    private func conversationContent(windowWidth: CGFloat) -> some View {
        let usesColumns = session.canEnd && horizontalSizeClass == .regular
            && windowWidth >= 760 && !dynamicTypeSize.isAccessibilitySize
        let layout = usesColumns
            ? AnyLayout(HStackLayout(alignment: .top, spacing: 32))
            : AnyLayout(VStackLayout(alignment: .leading, spacing: 24))

        return layout {
            VStack(alignment: .leading, spacing: 16) {
                sessionStatus
                #if DEBUG
                if let fixture, scenePhase == .active, session.canEnd {
                    ASLFixturePanel(fixture: fixture)
                }
                #endif
                if session.canEnd && session.phase != .listening && session.phase != .preparing {
                    restartControls
                }
            }
            .frame(maxWidth: usesColumns ? 252 : .infinity, alignment: .leading)

            if session.canEnd && (scenePhase != .active || showsCaptionTranscript) {
                Group {
                    if scenePhase == .active {
                        transcript
                    } else {
                        Label("Captions hidden", systemImage: "eye.slash")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: usesColumns ? 980 : 640, alignment: .leading)
    }

    private var sessionStatus: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("English captions", systemImage: "captions.bubble")
                .font(.title2.bold())
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("caption.status")
            statusMessage
            Label("ASL translation unavailable", systemImage: "hand.raised.slash")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button {
                showsASLPrivacy = true
            } label: {
                Label("ASL Privacy Details", systemImage: "info.circle")
                    .frame(minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .accessibilityIdentifier("asl.privacy.details")
        }
    }

    @ViewBuilder
    private var statusMessage: some View {
        switch session.phase {
        case .ready:
            Text("Caption nearby English speech on this device.")
        case .preparing:
            ProgressView("Preparing captions…")
        case .listening:
            Label("Listening on this device", systemImage: "mic.fill")
        case .finished:
            Text("Listening stopped. Continue captions or end the conversation.")
        case .interrupted, .failed(.interrupted):
            Text("The conversation was interrupted. Start a new conversation to resume captions.")
        case .failed(.permissionDenied):
            Text("Allow microphone and speech recognition access in Settings to start captions.")
        case .failed(.unavailable):
            Text("On-device English recognition is unavailable. Check that English recognition is available on this device, then try again.")
        case .failed(.recognitionFailed), .failed(.overloaded):
            Text("Captions stopped unexpectedly. Try starting them again.")
        case .oversized:
            Text("Captions stopped because the latest result was too long to display. Try starting them again.")
        }
    }

    private var showsCaptionTranscript: Bool {
        #if DEBUG
        fixture?.showsCaptions ?? true
        #else
        true
        #endif
    }

    private var transcript: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Live captions")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityFocused($liveFocused)
                    .accessibilityIdentifier("caption.live")
                if let latest = session.lines.last {
                    captionRow(latest, isLatest: true)
                        .id(latest.id)
                } else if session.phase == .listening {
                    Text("Waiting for speech…").foregroundStyle(.secondary)
                } else {
                    Text("Captions appear here during a conversation.")
                        .foregroundStyle(.secondary)
                }
            }
            .id(ScrollTarget.live)
            if session.lines.count > 1 {
                Text("Earlier captions")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                LazyVStack(alignment: .leading, spacing: 16) {
                    ForEach(session.lines.dropLast()) { line in
                        captionRow(line)
                    }
                }
            }
        }
    }

    private func captionRow(_ line: CaptionLine, isLatest: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if isLatest {
                captionText(line).accessibilityIdentifier("caption.latest")
            } else {
                captionText(line)
            }
            #if DEBUG
            if let omission = fixture?.translation.presentation.omissions[line.id] {
                ASLFixtureOmissionView(reason: omission)
            } else if let limit = fixture?.translation.presentation.captionLimits[line.id] {
                ASLFixtureOmissionView(limit: limit)
            }
            #endif
        }
    }

    private func captionText(_ line: CaptionLine) -> some View {
        Text(verbatim: line.text)
            .font(textSize.font)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityHint(line.isFinal ? Text("") : Text("Caption in progress"))
    }

    private func primaryStartButton(_ title: LocalizedStringKey) -> some View {
        Button {
            session.start()
        } label: {
            Label(title, systemImage: "mic")
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(minHeight: 44)
                .frame(maxWidth: 384)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .keyboardShortcut(.defaultAction)
    }

    private var restartControls: some View {
        VStack(alignment: .leading) {
            primaryStartButton("Continue Captions")
            #if canImport(UIKit)
            if session.phase == .failed(.permissionDenied),
               let url = URL(string: UIApplication.openSettingsURLString) {
                Button("Open Settings", systemImage: "gear") { openURL(url) }
                    .frame(minHeight: 44)
            }
            #endif
        }
    }

    private var opaqueSurface: Color {
        colorScheme == .dark ? .black : .white
    }

    @ViewBuilder
    private var controlSurface: some View {
        if reduceTransparency {
            opaqueSurface
        } else {
            Rectangle().fill(.regularMaterial)
        }
    }

    private func sessionControls(returnToLive: @escaping () -> Void) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack { controlButtons(returnToLive: returnToLive) }
            VStack { controlButtons(returnToLive: returnToLive) }
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .frame(maxWidth: .infinity)
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background { controlSurface }
    }

    @ViewBuilder
    private func controlButtons(returnToLive: @escaping () -> Void) -> some View {
        if !session.lines.isEmpty && scenePhase == .active && showsCaptionTranscript {
            Button("Return to Live", systemImage: "arrow.up", action: returnToLive)
                .keyboardShortcut("l", modifiers: [.command, .shift])
                .frame(minHeight: 44)
        }
        Button("End Conversation", role: .destructive) { session.end() }
            .accessibilityIdentifier("caption.end")
            .keyboardShortcut("e", modifiers: [.command, .shift])
            .frame(minHeight: 44)
    }
}

private enum ScrollTarget: Hashable { case live }

private enum CaptionTextSize: Hashable {
    case standard, large, extraLarge

    var font: Font {
        switch self {
        case .standard: .body
        case .large: .title3
        case .extraLarge: .title
        }
    }
}
