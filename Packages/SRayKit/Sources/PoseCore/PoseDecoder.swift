import Foundation

/// Experimental decoder for single-signer pose-format v0.2 data.
/// The supported profiles use homogeneous XYC or XYZC components.
public enum PoseDecoder {
    /// Byte budget shared with the transport's input envelope.
    public static let maximumEncodedBytes = 8 * 1_024 * 1_024
    private static let maximumHeaderBytes = 256 * 1_024
    private static let maximumComponents = 16
    private static let maximumLandmarks = 1_024
    private static let maximumConnections = 4_096
    private static let maximumFrames = 1_800

    /// Validates and decodes the original coordinates, confidence and component topology.
    /// A successful decode establishes structural validity for this profile.
    /// It does not establish hosted format compatibility or ASL interpretation.
    public static func decode(_ bytes: Data) throws -> PoseSequence {
        guard bytes.count <= maximumEncodedBytes else { throw PoseDecodingError.responseTooLarge }
        return try bytes.withUnsafeBytes { buffer in
            var reader = PoseByteReader(input: buffer, limit: min(buffer.count, maximumHeaderBytes))
            let header = try readHeader(from: &reader)
            reader.limit = buffer.count
            let fps = try reader.scalar()
            let frames = Int(try reader.wideWord())
            let people = try reader.word()
            guard people == 1 else { throw PoseDecodingError.invalidMetadata }
            guard (1...maximumFrames).contains(frames) else { throw PoseDecodingError.exceedsLimits }
            guard fps.isFinite, fps > 0, fps <= 120, Double(frames) / Double(fps) <= 60 else {
                throw PoseDecodingError.invalidTiming
            }

            // Values are bounded by the header and frame caps before multiplication.
            let samples = frames * header.landmarkCount
            let coordinateCount = samples * header.axes
            let expectedBytes = (coordinateCount + samples) * MemoryLayout<Float>.size
            if reader.remaining < expectedBytes { throw PoseDecodingError.truncated }
            if reader.remaining > expectedBytes { throw PoseDecodingError.trailingBytes }

            let coordinates = try readScalars(coordinateCount, from: &reader)
            let confidence = try readScalars(samples, from: &reader, within: 0...1)
            return PoseSequence(canvas: header.canvas, framesPerSecond: fps, frameCount: frames,
                                components: header.components, landmarkCount: header.landmarkCount,
                                axisCount: header.axes, coordinates: coordinates, confidence: confidence)
        }
    }

    private struct Header {
        let canvas: SIMD3<UInt16>
        let axes: Int
        let landmarkCount: Int
        let components: [PoseComponent]
    }

    private static func readHeader(from reader: inout PoseByteReader) throws -> Header {
        guard try reader.scalar() == Float(0.2) else { throw PoseDecodingError.unsupportedVersion }
        let canvas = SIMD3(try reader.word(), try reader.word(), try reader.word())
        let count = Int(try reader.word())
        guard canvas.x > 0, canvas.y > 0, count > 0 else { throw PoseDecodingError.invalidMetadata }
        guard count <= maximumComponents else { throw PoseDecodingError.exceedsLimits }

        var axes: Int?
        var landmarkCount = 0
        var connectionCount = 0
        var colorCount = 0
        var components: [PoseComponent] = []
        for _ in 0..<count {
            let name = try reader.name()
            let format = try reader.name()
            let componentAxes: Int
            switch format {
            case "XYC": componentAxes = 2
            case "XYZC": componentAxes = 3
            default: throw PoseDecodingError.unsupportedCoordinateFormat
            }
            guard axes == nil || axes == componentAxes else {
                throw PoseDecodingError.unsupportedCoordinateFormat
            }
            axes = componentAxes
            let landmarks = Int(try reader.word())
            let connections = Int(try reader.word())
            let colors = Int(try reader.word())
            guard landmarks > 0 else { throw PoseDecodingError.invalidMetadata }
            guard landmarks <= maximumLandmarks - landmarkCount,
                  connections <= maximumConnections - connectionCount,
                  colors <= maximumConnections - colorCount else { throw PoseDecodingError.exceedsLimits }

            let names = try (0..<landmarks).map { _ in try reader.name() }
            let links = try (0..<connections).map { _ in
                let start = Int(try reader.word())
                let end = Int(try reader.word())
                guard start < landmarks, end < landmarks else { throw PoseDecodingError.invalidConnection }
                return PoseConnection(start: landmarkCount + start, end: landmarkCount + end)
            }
            let palette = try (0..<colors).map { _ in SIMD3(try reader.word(), try reader.word(), try reader.word()) }
            let range = landmarkCount..<(landmarkCount + landmarks)
            components.append(PoseComponent(name: name, landmarkNames: names, landmarkRange: range,
                                            connections: links, colors: palette))
            landmarkCount += landmarks
            connectionCount += connections
            colorCount += colors
        }
        guard let axes else { throw PoseDecodingError.invalidMetadata }
        return Header(canvas: canvas, axes: axes, landmarkCount: landmarkCount, components: components)
    }

    private static func readScalars(
        _ count: Int, from reader: inout PoseByteReader, within range: ClosedRange<Float>? = nil
    ) throws -> [Float] {
        var values: [Float] = []
        values.reserveCapacity(count)
        for index in 0..<count {
            if index.isMultiple(of: 4_096) { try Task.checkCancellation() }
            let value = try reader.scalar()
            guard value.isFinite, range?.contains(value) ?? true else { throw PoseDecodingError.invalidSample }
            values.append(value)
        }
        return values
    }
}
