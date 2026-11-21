import Foundation

/// A transport failure that may advise how long to defer a new user-initiated request.
package protocol TranslationRetryAdvising: Error {
    /// Returns a relative delay using the supplied wall clock for absolute deadlines.
    /// Nil leaves recovery to the ordinary explicit-resume flow.
    func retryDelay(relativeTo date: Date) -> Duration?
}
