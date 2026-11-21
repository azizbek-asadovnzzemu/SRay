import Foundation
import PoseCore
import SwiftUI

/// An experimental viewer for an already validated and locally retained clip.
public struct PosePlaybackView: View {
    private let presentation: PosePresentation
    private let sharedStartedAt: ContinuousClock.Instant?
    private let onStart: (@MainActor () -> Void)?
    private let onFinish: (@MainActor () -> Void)?
    @State private var playhead = PosePlayhead()
    @State private var origin = ContinuousClock.now
    @State private var completedSharedPlayback = false

    /// Creates a stopped viewer. Playing and replaying both require user input.
    public init(presentation: PosePresentation) {
        self.presentation = presentation
        sharedStartedAt = nil
        onStart = nil
        onFinish = nil
    }

    /// Creates an automatically played clip whose owner supplies the replay controls.
    public init(presentation: PosePresentation, onFinish: @escaping @MainActor () -> Void) {
        self.presentation = presentation
        sharedStartedAt = nil
        onStart = nil
        self.onFinish = onFinish
    }

    /// Presents a shared attempt at its current position, including in a late-opening window.
    package init(
        presentation: PosePresentation,
        sharedStartedAt: ContinuousClock.Instant?,
        onStart: @escaping @MainActor () -> Void,
        onFinish: @escaping @MainActor () -> Void
    ) {
        self.presentation = presentation
        self.sharedStartedAt = sharedStartedAt
        self.onStart = onStart
        self.onFinish = onFinish
    }

    public var body: some View {
        let sequence = presentation.sequence
        VStack(alignment: .leading, spacing: 12) {
            TimelineView(.animation(minimumInterval: 1 / Double(sequence.framesPerSecond), paused: timelinePaused)) { _ in
                let instant = elapsedSinceOrigin
                let displayedPlayhead = sharedStartedAt.map { PosePlayhead(startedAt: origin.duration(to: $0)) } ?? playhead
                let elapsed = displayedPlayhead.elapsed(at: instant, duration: sequence.durationSeconds)
                let frame = displayedPlayhead.frame(at: instant, framesPerSecond: Double(sequence.framesPerSecond),
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
                .onChange(of: elapsed >= sequence.durationSeconds, initial: onStart != nil) { _, ended in
                    guard ended, !completedSharedPlayback else { return }
                    if onStart == nil {
                        playhead.pause(at: elapsedSinceOrigin, duration: sequence.durationSeconds)
                    } else {
                        completedSharedPlayback = true
                    }
                    onFinish?()
                }
            }

            if onFinish == nil {
                ViewThatFits(in: .horizontal) {
                    HStack { controls }
                    VStack(alignment: .leading) { controls }
                }
                .buttonStyle(.bordered)
            }
        }
        .onAppear {
            if let onStart {
                onStart()
            } else if onFinish != nil {
                playhead.play(at: elapsedSinceOrigin)
            }
        }
        .onDisappear {
            if onStart == nil { playhead.pause(at: elapsedSinceOrigin, duration: sequence.durationSeconds) }
        }
    }

    private var timelinePaused: Bool {
        if onStart != nil { return completedSharedPlayback || sharedStartedAt == nil }
        return !playhead.isPlaying
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
