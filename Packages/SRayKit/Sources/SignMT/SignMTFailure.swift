import Foundation
import PoseCore

/// Content-free outcomes for the observed Sign MT transport contract.
enum SignMTFailure: Error, Equatable, Sendable {
    case invalidText
    case requestTooLarge
    case offline
    case timedOut
    case unauthorized
    case rateLimited(retryAfter: RetryAfter?)
    case redirectRejected
    case unavailable
    case unexpectedStatus(Int)
    case invalidResponse
    case invalidPose(PoseDecodingError)
    case responseTooLarge
}

/// A provider's retry deadline. The app must still require explicit recovery.
enum RetryAfter: Equatable, Sendable {
    case delay(Duration)
    case date(Date)

    /// Parses either standard form of the Retry-After header.
    init?(_ header: String?) {
        guard let value = header?.trimmingCharacters(in: .whitespacesAndNewlines) else { return nil }
        if let seconds = Int64(value), seconds >= 0 {
            self = .delay(.seconds(seconds))
            return
        }
        let style = Date.ParseStrategy(
            format: "\(weekday: .abbreviated), \(day: .twoDigits) \(month: .abbreviated) \(year: .defaultDigits) \(hour: .twoDigits(clock: .twentyFourHour, hourCycle: .zeroBased)):\(minute: .twoDigits):\(second: .twoDigits) GMT",
            locale: Locale(identifier: "en_US_POSIX"),
            timeZone: .gmt,
            isLenient: false
        )
        guard let date = try? style.parse(value) else { return nil }
        self = .date(date)
    }
}
