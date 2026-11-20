/// One signer across a bounded sequence of frames, in source coordinates.
public struct PoseSequence: Sendable {
    /// Declared source dimensions. The fields do not imply a world orientation.
    public let canvas: SIMD3<UInt16>
    /// Frames per second in the original sequence.
    public let framesPerSecond: Float
    /// Number of decoded frames.
    public let frameCount: Int
    /// Components in source order, with independent landmark names and links.
    public let components: [PoseComponent]
    /// Number of flattened landmarks in one frame.
    public let landmarkCount: Int
    /// Duration of all frames, including the interval occupied by the last frame.
    public var durationSeconds: Double { Double(frameCount) / Double(framesPerSecond) }

    let axisCount: Int
    let coordinates: [Float]
    let confidence: [Float]

    /// Returns one source landmark, or nil for an invalid index or a masked point.
    /// Z is absent for two-dimensional sequences. Values are never mirrored or normalized.
    public func landmark(at index: Int, inFrame frame: Int) -> PoseLandmark? {
        guard (0..<frameCount).contains(frame), (0..<landmarkCount).contains(index) else { return nil }
        let sample = frame * landmarkCount + index
        let score = confidence[sample]
        guard score > 0 else { return nil }
        let offset = sample * axisCount
        return PoseLandmark(x: coordinates[offset], y: coordinates[offset + 1],
                            z: axisCount == 3 ? coordinates[offset + 2] : nil,
                            confidence: score)
    }
}

/// Layout metadata for one named group of landmarks.
public struct PoseComponent: Sendable {
    /// Component name supplied by the source.
    public let name: String
    /// Landmark names ordered as encoded.
    public let landmarkNames: [String]
    /// Global indices for this component's landmarks in each frame.
    public let landmarkRange: Range<Int>
    /// Links encoded as global landmark indices.
    public let connections: [PoseConnection]
    /// Original RGB metadata in source order.
    public let colors: [SIMD3<UInt16>]
}

/// A line between two decoded landmarks.
public struct PoseConnection: Equatable, Sendable {
    /// First endpoint in the sequence's flattened landmark order.
    public let start: Int
    /// Second endpoint in the sequence's flattened landmark order.
    public let end: Int
}

/// One visible measurement in a decoded frame.
public struct PoseLandmark: Equatable, Sendable {
    /// Horizontal value from the source.
    public let x: Float
    /// Vertical value from the source.
    public let y: Float
    /// Depth value when the source uses XYZ coordinates.
    public let z: Float?
    /// Visible confidence in the interval (0, 1].
    public let confidence: Float
}
