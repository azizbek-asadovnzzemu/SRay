import Foundation

/// Reads unaligned little-endian fields from a bounded region of input.
struct PoseByteReader {
    let input: UnsafeRawBufferPointer
    private(set) var offset = 0
    var limit: Int

    var remaining: Int { limit - offset }

    mutating func word() throws -> UInt16 {
        try readInteger(UInt16.self)
    }

    mutating func wideWord() throws -> UInt32 {
        try readInteger(UInt32.self)
    }

    mutating func scalar() throws -> Float {
        Float(bitPattern: try wideWord())
    }

    mutating func name() throws -> String {
        let length = Int(try word())
        guard (1...256).contains(length) else { throw PoseDecodingError.invalidMetadata }
        guard length <= remaining else { throw PoseDecodingError.truncated }
        let start = offset
        offset += length
        guard let result = String(bytes: input[start..<offset], encoding: .utf8) else {
            throw PoseDecodingError.invalidMetadata
        }
        return result
    }

    private mutating func readInteger<T: FixedWidthInteger>(_ type: T.Type) throws -> T {
        let size = MemoryLayout<T>.size
        guard size <= remaining else { throw PoseDecodingError.truncated }
        let result = input.loadUnaligned(fromByteOffset: offset, as: type)
        offset += size
        return T(littleEndian: result)
    }
}
