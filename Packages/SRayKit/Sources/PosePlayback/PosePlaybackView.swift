import Foundation
import PoseCore
import SwiftUI

/// An experimental viewer for an already validated and locally retained clip.
public struct PosePlaybackView: View {
    private let presentation: PosePresentation
    @State private var playhead = PosePlayhead()
    @State private var origin = ContinuousClock.now

    /// Creates a stopped viewer. Playing and replaying both require user input.
    public init(presentation: PosePresentation) {
        self.presentation = presentation
    }

    public var body: some View {
        let sequence = presentation.sequence
        VStack(alignment: .leading, spacing: 12) {
            TimelineView(.animation(minimumInterval: 1 / Double(sequence.framesPerSecond), paused: !playhead.isPlaying)) { _ in
                let instant = elapsedSinceOrigin
                let elapsed = playhead.elapsed(at: instant, duration: sequence.durationSeconds)
                let frame = playhead.frame(at: instant, framesPerSecond: Double(sequence.framesPerSecond),
                                           frameCount: sequence.frameCount)
                VStack(alignment: .leading) {
                    Canvas { context, size in
                        draw(frame: frame, in: context, size: size)
                    }
                    .aspectRatio(Double(sequence.canvas.x) / Double(sequence.canvas.y), contentMode: .fit)
                    .accessibilityLabel("Pose playback")
                    Text(Duration.seconds(elapsed), format: .time(pattern: .minuteSecond))
                        .monospacedDigit()
                        .accessibilityLabel(Text(Duration.seconds(elapsed), format: .units(allowed: [.minutes, .seconds])))
                }
                .onChange(of: elapsed >= sequence.durationSeconds) { _, ended in
                    if ended {
                        playhead.pause(at: elapsedSinceOrigin, duration: sequence.durationSeconds)
                    }
                }
            }

            ViewThatFits(in: .horizontal) {
                HStack { controls }
                VStack(alignment: .leading) { controls }
            }
            .buttonStyle(.bordered)
        }
        .onDisappear { playhead.pause(at: elapsedSinceOrigin, duration: sequence.durationSeconds) }
    }

    private var elapsedSinceOrigin: Duration { origin.duration(to: .now) }

    @ViewBuilder private var controls: some View {
        Button(playhead.isPlaying ? "Pause" : "Play", systemImage: playhead.isPlaying ? "pause.fill" : "play.fill") {
            let now = elapsedSinceOrigin
            let duration = presentation.sequence.durationSeconds
            if playhead.isPlaying {
                playhead.pause(at: now, duration: duration)
            } else if playhead.elapsed(at: now, duration: duration) >= duration {
                playhead.replay(at: now)
            } else {
                playhead.play(at: now)
            }
        }
        .frame(minHeight: 44)
        Button("Replay", systemImage: "arrow.counterclockwise") {
            playhead.replay(at: elapsedSinceOrigin)
        }
        .frame(minHeight: 44)
    }

    private func draw(frame: Int, in context: GraphicsContext, size: CGSize) {
        guard let transform = presentation.transform(toFit: size) else { return }
        let sequence = presentation.sequence
        var lines = Path()
        var dots = Path()
        for component in sequence.components {
            for connection in component.connections {
                guard let start = location(connection.start), let end = location(connection.end) else { continue }
                lines.move(to: start)
                lines.addLine(to: end)
            }
            for index in component.landmarkRange {
                guard let point = location(index) else { continue }
                dots.addEllipse(in: CGRect(x: point.x - 2, y: point.y - 2, width: 4, height: 4))
            }
        }
        context.stroke(lines, with: .foreground, lineWidth: 2)
        context.fill(dots, with: .foreground)

        func location(_ index: Int) -> CGPoint? {
            guard let point = sequence.landmark(at: index, inFrame: frame) else { return nil }
            return CGPoint(x: CGFloat(point.x), y: CGFloat(point.y)).applying(transform)
        }
    }
}

#if DEBUG
#Preview("Geometry only") {
    if let sequence = try? PoseDecoder.decode(SyntheticPoseFixture.encoded()) {
        PosePlaybackView(presentation: PosePresentation(sequence: sequence))
            .padding()
    }
}
#endif
