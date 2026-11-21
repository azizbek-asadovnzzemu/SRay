import Foundation
import os

/// Streams one response into bounded memory without retaining framework errors or request metadata.
final class SignMTResponseDelegate: NSObject, URLSessionDataDelegate {
    private struct Response: Sendable {
        var acceptedHeaders = false
        var bytes = Data()
        var failure: SignMTFailure?
    }

    private let response = OSAllocatedUnfairLock(initialState: Response())
    private let outcome: AsyncThrowingStream<ReceivedPose, any Error>.Continuation

    init(outcome: AsyncThrowingStream<ReceivedPose, any Error>.Continuation) {
        self.outcome = outcome
    }

    func urlSession(
        _ session: URLSession, dataTask: URLSessionDataTask, didReceive incoming: URLResponse,
        completionHandler: @escaping @Sendable (URLSession.ResponseDisposition) -> Void
    ) {
        do {
            try SignMTClient.validate(incoming)
            response.withLock { $0.acceptedHeaders = true }
            completionHandler(.allow)
        } catch {
            response.withLock { $0.failure = error }
            completionHandler(.cancel)
        }
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        let accepted = response.withLock { state in
            guard state.acceptedHeaders, state.failure == nil else { return false }
            guard data.count <= SignMTClient.maximumResponseBytes - state.bytes.count else {
                state.bytes = Data()
                state.failure = .responseTooLarge
                return false
            }
            state.bytes.append(data)
            return true
        }
        if !accepted { dataTask.cancel() }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
        let completed = response.withLock { state in
            let completed = state
            state = Response()
            return completed
        }
        if let failure = completed.failure {
            outcome.finish(throwing: failure)
        } else if let error {
            outcome.finish(throwing: Self.safeError(error))
        } else if completed.acceptedHeaders, !completed.bytes.isEmpty {
            outcome.yield(ReceivedPose(bytes: completed.bytes))
            outcome.finish()
        } else {
            outcome.finish(throwing: SignMTFailure.invalidResponse)
        }
    }

    /// Rejects all redirects until the approved provider contract permits a destination.
    func urlSession(
        _ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection redirect: HTTPURLResponse,
        newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }

    /// Maps loader errors without propagating a URL, underlying error, or associated description.
    private static func safeError(_ error: any Error) -> any Error {
        guard let urlError = error as? URLError else { return SignMTFailure.unavailable }
        switch urlError.code {
        case .cancelled: return CancellationError()
        case .notConnectedToInternet, .networkConnectionLost: return SignMTFailure.offline
        case .timedOut: return SignMTFailure.timedOut
        default: return SignMTFailure.unavailable
        }
    }
}
