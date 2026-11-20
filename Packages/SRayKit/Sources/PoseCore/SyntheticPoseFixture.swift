#if DEBUG
import Foundation

/// Original geometric points for decoder tests and local renderer previews.
package enum SyntheticPoseFixture {
    /// Builds two frames of asymmetric motion in a 320 by 240 canvas.
    package static func encoded(
        format: String = "XYC", fps: Float = 2, frames: UInt32 = 2, people: UInt16 = 1,
        secondEndpoint: UInt16 = 1, firstCoordinate: Float = 70, lastConfidence: Float = 0,
        extraComponentFormat: String? = nil
    ) -> Data {
        var bytes = Data()
        func write<T: FixedWidthInteger>(_ value: T) {
            withUnsafeBytes(of: value.littleEndian) { bytes.append(contentsOf: $0) }
        }
        func writeName(_ name: String) {
            write(UInt16(name.utf8.count))
            bytes.append(contentsOf: name.utf8)
        }

        write(Float(0.2).bitPattern)
        write(UInt16(320))
        write(UInt16(240))
        write(UInt16(format == "XYZC" ? 32 : 0))
        write(UInt16(extraComponentFormat == nil ? 1 : 2))
        writeName("GEOMETRIC")
        writeName(format)
        write(UInt16(2))
        write(UInt16(1))
        write(UInt16(1))
        writeName("LEFT_POINT")
        writeName("RIGHT_POINT")
        write(UInt16(0))
        write(secondEndpoint)
        write(UInt16(30))
        write(UInt16(60))
        write(UInt16(90))
        if let extraComponentFormat {
            writeName("DETAIL")
            writeName(extraComponentFormat)
            write(UInt16(2))
            write(UInt16(1))
            write(UInt16(0))
            writeName("TOP_DETAIL")
            writeName("BOTTOM_DETAIL")
            write(UInt16(0))
            write(UInt16(1))
        }

        write(fps.bitPattern)
        write(frames)
        write(people)
        var locations: [[Float]] = [[firstCoordinate, 100], [235, 170], [55, 80], [245, 175]]
        var scores = [Float(1), 0.5, 1, lastConfidence]
        if extraComponentFormat != nil {
            locations.insert(contentsOf: [[40, 50], [40, 60]], at: 2)
            locations.append(contentsOf: [[41, 50], [41, 60]])
            scores.insert(contentsOf: [1, 0.25], at: 2)
            scores.append(contentsOf: [1, 1])
        }
        for (index, location) in locations.enumerated() {
            for coordinate in location { write(coordinate.bitPattern) }
            if format == "XYZC" { write(Float(index + 10).bitPattern) }
        }
        for score in scores { write(score.bitPattern) }
        return bytes
    }
}
#endif
