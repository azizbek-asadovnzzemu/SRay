import CoreGraphics
import PoseCore

/// A pose and its fixed projection envelope, prepared once before presenting it.
public struct PosePresentation: Sendable {
    let sequence: PoseSequence
    let sourceBounds: CGRect

    /// Includes the full declared canvas and every visible point in the projection.
    /// - Complexity: O(frames × landmarks). Prepare on a worker before rendering.
    public init(sequence: PoseSequence) {
        self.sequence = sequence
        var minX: CGFloat = 0
        var minY: CGFloat = 0
        var maxX = CGFloat(sequence.canvas.x)
        var maxY = CGFloat(sequence.canvas.y)
        for frame in 0..<sequence.frameCount {
            for index in 0..<sequence.landmarkCount {
                guard let point = sequence.landmark(at: index, inFrame: frame) else { continue }
                minX = min(minX, CGFloat(point.x))
                minY = min(minY, CGFloat(point.y))
                maxX = max(maxX, CGFloat(point.x))
                maxY = max(maxY, CGFloat(point.y))
            }
        }
        sourceBounds = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    /// Fits the complete projection inside the drawable area without flipping an axis.
    func transform(toFit size: CGSize, padding: CGFloat = 12) -> CGAffineTransform? {
        let space = CGSize(width: size.width - padding * 2, height: size.height - padding * 2)
        guard space.width > 0, space.height > 0 else { return nil }
        let scale = min(space.width / sourceBounds.width, space.height / sourceBounds.height)
        return CGAffineTransform(
            a: scale, b: 0, c: 0, d: scale,
            tx: (size.width - sourceBounds.width * scale) / 2 - sourceBounds.minX * scale,
            ty: (size.height - sourceBounds.height * scale) / 2 - sourceBounds.minY * scale
        )
    }
}
