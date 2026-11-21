#if DEBUG
import ConversationCore
import PosePlayback
import SwiftUI

/// Controls the opt-in fixture and presents the current attempt under its display identity.
struct ASLFixturePanel: View {
    let fixture: ASLFixtureConversation

    var body: some View {
        let translation = fixture.translation
        let presentation = translation.presentation
        VStack(alignment: .leading, spacing: 8) {
            Text("Synthetic pose demo")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            status(for: presentation.state, failed: presentation.serviceFailed)
                .accessibilityIdentifier("asl.demo.status")

            if presentation.state == .enabled {
                Button("Pause Demo", systemImage: "pause", action: translation.pause)
                    .accessibilityIdentifier("asl.demo.pause")
            } else {
                Button(presentation.state == .paused ? "Resume Demo" : "Enable Demo",
                       systemImage: "play", action: translation.enable)
                    .accessibilityIdentifier("asl.demo.enable")
            }
            if fixture.captions.phase == .listening {
                Button("Show Sample Caption", systemImage: "captions.bubble", action: fixture.showSampleCaption)
                    .accessibilityIdentifier("asl.demo.sample")
            }
            if let playback = presentation.playing {
                PosePlaybackView(presentation: PosePresentation(sequence: playback.translation.clip)) {
                    translation.finishPlayback(id: playback.id)
                }
                .id(playback.id)
            } else if presentation.canReplay {
                Button("Replay Sample", systemImage: "arrow.counterclockwise", action: translation.replay)
                    .accessibilityIdentifier("asl.demo.replay")
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .task(id: presentation.ready?.token) {
            guard let ready = presentation.ready, !Task.isCancelled else { return }
            translation.beginPlayback(for: ready.token)
        }
    }

    @ViewBuilder
    private func status(for state: TranslationGateState, failed: Bool) -> some View {
        if failed {
            Label("Demo unavailable. Resume to try again.", systemImage: "exclamationmark.triangle")
        } else {
            switch state {
            case .idle, .captionsOnly:
                Label("Demo off", systemImage: "stop.circle")
            case .enabled:
                Label("Demo active", systemImage: "play.circle")
            case .paused:
                Label("Demo paused", systemImage: "pause.circle")
            case .interrupted:
                Label("Demo interrupted", systemImage: "stop.circle")
            }
        }
    }
}
#endif
