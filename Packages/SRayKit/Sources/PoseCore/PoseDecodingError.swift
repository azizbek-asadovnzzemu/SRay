/// Content-free reasons an encoded pose cannot be accepted.
public enum PoseDecodingError: Error, Equatable, Sendable {
    case responseTooLarge
    case truncated
    case unsupportedVersion
    case unsupportedCoordinateFormat
    case invalidMetadata
    case exceedsLimits
    case invalidConnection
    case invalidTiming
    case invalidSample
    case trailingBytes
}
