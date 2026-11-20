import ConversationCore
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// A window into the shared conversation, with independent reading controls.
public struct ConversationView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.openURL) private var openURL
    @State private var windowID = UUID()
    @State private var textSize: CaptionTextSize = .standard
    @AccessibilityFocusState private var liveFocused: Bool
    private let session: CaptionSession

    /// Creates a window for the app-owned caption session.
    public init(session: CaptionSession) {
        self.session = session
    }

    public var body: some View {
        NavigationStack {
            GeometryReader { window in
                ScrollViewReader { proxy in
                    ScrollView {
                        conversationContent(windowWidth: window.size.width)
                            .padding()
                            .frame(maxWidth: .infinity)
                    }
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        if session.canEnd {
                            sessionControls {
                                proxy.scrollTo(ScrollTarget.live, anchor: .top)
                                liveFocused = true
                            }
                        } else {
                            primaryStartButton(dynamicTypeSize.isAccessibilitySize ? "Start Captions" : "Start Conversation")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(.regularMaterial)
                        }
                    }
                }
            }
            .navigationTitle("SRay")
            #if os(iOS)
            .navigationBarTitleDisplayMode(dynamicTypeSize.isAccessibilitySize ? .inline : .automatic)
            #endif
            .toolbar {
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
                if session.canEnd && session.phase != .listening && session.phase != .preparing {
                    restartControls
                }
            }
            .frame(maxWidth: usesColumns ? 252 : .infinity, alignment: .leading)

            if session.canEnd {
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
            statusMessage
            Label("ASL translation unavailable", systemImage: "hand.raised.slash")
                .font(.subheadline)
                .foregroundStyle(.secondary)
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

    private var transcript: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Live captions")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityFocused($liveFocused)
                if let latest = session.lines.last {
                    captionText(latest)
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
                        captionText(line)
                    }
                }
            }
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
        .background(.regularMaterial)
    }

    @ViewBuilder
    private func controlButtons(returnToLive: @escaping () -> Void) -> some View {
        if !session.lines.isEmpty && scenePhase == .active {
            Button("Return to Live", systemImage: "arrow.up", action: returnToLive)
                .keyboardShortcut("l", modifiers: [.command, .shift])
                .frame(minHeight: 44)
        }
        Button("End Conversation", role: .destructive) { session.end() }
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
