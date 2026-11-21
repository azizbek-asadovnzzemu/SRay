#if DEBUG
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

            if presentation.state == .enabled {
                Button("Pause Demo", systemImage: "pause", action: translation.pause)
                    .accessibilityIdentifier("asl.demo.pause")
            } else {
                Button(presentation.state == .paused ? "Resume Demo" : "Enable Demo",
                       systemImage: "play", action: fixture.enableDemo)
                    .accessibilityIdentifier("asl.demo.enable")
            }
            if fixture.captions.phase == .listening {
                Button("Show Sample Caption", systemImage: "captions.bubble", action: fixture.showSampleCaption)
                    .accessibilityIdentifier("asl.demo.sample")
            }
            ASLFixtureOutputPicker(fixture: fixture)
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
}
#endif
