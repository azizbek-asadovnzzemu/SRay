import Foundation
import Testing
@testable import PoseCore

/// Checks the accepted profile with original geometry and bounded malformed input.
struct PoseDecoderTests {
    @Test func preservesAsymmetryTopologyAndConfidence() throws {
        // Arrange
        let bytes = SyntheticPoseFixture.encoded()

        // Act
        let sequence = try PoseDecoder.decode(bytes)

        // Assert
        #expect(sequence.canvas == SIMD3(320, 240, 0))
        #expect(sequence.frameCount == 2)
        #expect(sequence.framesPerSecond == 2)
        #expect(sequence.durationSeconds == 1)
        #expect(sequence.components.first?.landmarkNames == ["LEFT_POINT", "RIGHT_POINT"])
        #expect(sequence.components.first?.connections == [.init(start: 0, end: 1)])
        #expect(sequence.components.first?.colors == [SIMD3(30, 60, 90)])
        #expect(sequence.landmark(at: 0, inFrame: 0) == .init(x: 70, y: 100, z: nil, confidence: 1))
        #expect(sequence.landmark(at: 1, inFrame: 0) == .init(x: 235, y: 170, z: nil, confidence: 0.5))
        #expect(sequence.landmark(at: 0, inFrame: 1)?.x == 55)
        #expect(sequence.landmark(at: 1, inFrame: 1) == nil)
        #expect(sequence.landmark(at: -1, inFrame: 0) == nil)
        #expect(sequence.landmark(at: 0, inFrame: 2) == nil)
    }

    @Test func preservesDepthInThreeDimensionalProfile() throws {
        // Arrange
        let bytes = SyntheticPoseFixture.encoded(format: "XYZC")

        // Act
        let sequence = try PoseDecoder.decode(bytes)

        // Assert
        #expect(sequence.canvas.z == 32)
        #expect(sequence.landmark(at: 0, inFrame: 0)?.z == 10)
        #expect(sequence.landmark(at: 0, inFrame: 1)?.z == 12)
    }

    @Test func mapsMultipleComponentsIntoEachFrame() throws {
        // Arrange
        let bytes = SyntheticPoseFixture.encoded(extraComponentFormat: "XYC")

        // Act
        let sequence = try PoseDecoder.decode(bytes)

        // Assert
        #expect(sequence.landmarkCount == 4)
        #expect(sequence.components.last?.landmarkRange == 2..<4)
        #expect(sequence.components.last?.connections == [.init(start: 2, end: 3)])
        #expect(sequence.landmark(at: 3, inFrame: 0) == .init(x: 40, y: 60, z: nil, confidence: 0.25))
        #expect(sequence.landmark(at: 2, inFrame: 1)?.x == 41)
        #expect(throws: PoseDecodingError.unsupportedCoordinateFormat) {
            try PoseDecoder.decode(SyntheticPoseFixture.encoded(extraComponentFormat: "XYZC"))
        }
    }

    @Test func rejectsEveryTruncatedPrefixAndTrailingBytes() {
        // Arrange
        let full = SyntheticPoseFixture.encoded()

        // Act and assert
        for end in 0..<full.count {
            let prefix = Data(full.prefix(end))
            #expect(throws: PoseDecodingError.truncated, "Byte count \(end)") {
                try PoseDecoder.decode(prefix)
            }
        }
        #expect(throws: PoseDecodingError.trailingBytes) {
            try PoseDecoder.decode(full + Data([0]))
        }
    }

    @Test(arguments: [Float.nan, .infinity, -1, 0, 0.01, 121])
    func rejectsInvalidFrameTiming(fps: Float) {
        // Arrange
        let bytes = SyntheticPoseFixture.encoded(fps: fps)

        // Act and assert
        #expect(throws: PoseDecodingError.invalidTiming) { try PoseDecoder.decode(bytes) }
    }

    @Test(arguments: [Float.nan, .infinity, -.infinity])
    func rejectsNonFiniteCoordinates(value: Float) {
        // Arrange
        let bytes = SyntheticPoseFixture.encoded(firstCoordinate: value)

        // Act and assert
        #expect(throws: PoseDecodingError.invalidSample) { try PoseDecoder.decode(bytes) }
    }

    @Test(arguments: [Float.nan, .infinity, -0.01, 1.01])
    func rejectsInvalidConfidence(value: Float) {
        // Arrange
        let bytes = SyntheticPoseFixture.encoded(lastConfidence: value)

        // Act and assert
        #expect(throws: PoseDecodingError.invalidSample) { try PoseDecoder.decode(bytes) }
    }

    @Test func rejectsUnsupportedMetadataAndInvalidTopology() {
        // Arrange
        let valid = SyntheticPoseFixture.encoded()
        var unknownVersion = valid
        unknownVersion[0] = 0
        var invalidName = valid
        invalidName[14] = 0xFF

        // Act and assert
        #expect(throws: PoseDecodingError.unsupportedVersion) { try PoseDecoder.decode(unknownVersion) }
        #expect(throws: PoseDecodingError.invalidMetadata) { try PoseDecoder.decode(invalidName) }
        #expect(throws: PoseDecodingError.unsupportedCoordinateFormat) {
            try PoseDecoder.decode(SyntheticPoseFixture.encoded(format: "XYZKC"))
        }
        #expect(throws: PoseDecodingError.invalidMetadata) {
            try PoseDecoder.decode(SyntheticPoseFixture.encoded(people: 2))
        }
        #expect(throws: PoseDecodingError.invalidConnection) {
            try PoseDecoder.decode(SyntheticPoseFixture.encoded(secondEndpoint: 2))
        }
    }

    @Test func rejectsOverLimitResponseAndFrameCountBeforeSampleAllocation() {
        // Arrange
        let bytes = Data(count: PoseDecoder.maximumEncodedBytes + 1)
        let frames = SyntheticPoseFixture.encoded(frames: UInt32.max)

        // Act and assert
        #expect(throws: PoseDecodingError.responseTooLarge) { try PoseDecoder.decode(bytes) }
        #expect(throws: PoseDecodingError.exceedsLimits) { try PoseDecoder.decode(frames) }
    }
}
