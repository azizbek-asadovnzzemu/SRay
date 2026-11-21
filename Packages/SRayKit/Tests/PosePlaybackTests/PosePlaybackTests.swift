import CoreGraphics
import PoseCore
import Testing
@testable import PosePlayback

struct PosePlaybackTests {
    @Test func pauseAndReplayKeepSourceFrameOrder() {
        // Arrange
        var playhead = PosePlayhead()
        playhead.play(at: .seconds(3))

        // Act
        let frame = playhead.frame(at: .milliseconds(3_600), framesPerSecond: 2, frameCount: 3)
        playhead.pause(at: .milliseconds(3_600), duration: 1.5)
        let held = playhead.frame(at: .seconds(20), framesPerSecond: 2, frameCount: 3)
        playhead.play(at: .seconds(20))
        let resumed = playhead.frame(at: .milliseconds(20_550), framesPerSecond: 2, frameCount: 3)
        let ended = playhead.frame(at: .seconds(25), framesPerSecond: 2, frameCount: 3)
        playhead.replay(at: .seconds(25))

        // Assert
        #expect(frame == 1)
        #expect(held == 1)
        #expect(resumed == 2)
        #expect(ended == 2)
        #expect(playhead.frame(at: .seconds(25), framesPerSecond: 2, frameCount: 3) == 0)
    }

    @Test func lateWindowUsesTheSharedPlaybackPosition() {
        let originalWindow = PosePlayhead(startedAt: .seconds(2))
        let lateWindow = PosePlayhead(startedAt: .milliseconds(-350))
        #expect(originalWindow.frame(at: .milliseconds(2_750), framesPerSecond: 10, frameCount: 20) == 7)
        #expect(lateWindow.frame(at: .milliseconds(400), framesPerSecond: 10, frameCount: 20) == 7)
        #expect(lateWindow.frame(at: .seconds(4), framesPerSecond: 10, frameCount: 20) == 19)
    }

    @Test(arguments: [CGSize(width: 100, height: 300), CGSize(width: 300, height: 100)])
    func projectionFitsFullClipWithoutMirroring(size: CGSize) throws {
        // Arrange
        let sequence = try PoseDecoder.decode(SyntheticPoseFixture.encoded(firstCoordinate: -45))
        let presentation = PosePresentation(sequence: sequence)

        // Act
        let transform = try #require(presentation.transform(toFit: size))
        let left = CGPoint(x: -45, y: 100).applying(transform)
        let right = CGPoint(x: 235, y: 170).applying(transform)
        let bounds = presentation.sourceBounds.applying(transform)

        // Assert
        #expect(left.x < right.x)
        #expect(bounds.minX >= 11.99)
        #expect(bounds.minY >= 11.99)
        #expect(bounds.maxX <= size.width - 11.99)
        #expect(bounds.maxY <= size.height - 11.99)
    }

    @Test func tinyViewHasNoProjection() throws {
        // Arrange
        let sequence = try PoseDecoder.decode(SyntheticPoseFixture.encoded())
        let presentation = PosePresentation(sequence: sequence)

        // Act
        let transform = presentation.transform(toFit: CGSize(width: 20, height: 20))

        // Assert
        #expect(transform == nil)
    }
}
