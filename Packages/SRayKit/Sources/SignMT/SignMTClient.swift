import Foundation

/// Size-checked transport bytes. A pose decoder must validate them before playback.
struct ReceivedPose: Sendable {
    /// Encoded pose, bounded by the client before receipt completes.
    let bytes: Data
}

/// Isolated client for the observed English-to-ASL endpoint.
/// This target is intentionally absent from the app's product graph until
/// production access and the pose contract are established.
final class SignMTClient: Sendable {
    /// The transport ceiling, separate from the shorter first-frame deadline.
    static let timeout: TimeInterval = 15
    /// Maximum body bytes accepted from the provider.
    static let maximumResponseBytes = 8 * 1_024 * 1_024
    /// Upper bound before percent-encoding.
    private static let maximumTextBytes = 4_096
    /// Upper bound on the complete encoded request URL.
    private static let maximumURLBytes = 8_192

    private let protocolClass: URLProtocol.Type?

    /// Uses the platform loader by default. Tests inject a synthetic URL protocol.
    init(protocolClass: URLProtocol.Type? = nil) {
        self.protocolClass = protocolClass
    }

    /// Starts the request synchronously and returns its cancellation handle before any await.
    /// Call this inside the transmission gate's dispatch closure.
    func startTranslation(_ text: String) throws(SignMTFailure) -> SignMTSubmission {
        let request = try Self.makeRequest(text: text)
        let config = URLSessionConfiguration.ephemeral
        config.urlCache = nil
        config.httpCookieStorage = nil
        config.httpShouldSetCookies = false
        config.urlCredentialStorage = nil
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.timeoutIntervalForRequest = Self.timeout
        config.timeoutIntervalForResource = Self.timeout
        config.waitsForConnectivity = false
        if let protocolClass { config.protocolClasses = [protocolClass] }

        let (poses, outcome) = AsyncThrowingStream<ReceivedPose, any Error>.makeStream(
            bufferingPolicy: .bufferingNewest(1)
        )
        let delegate = SignMTResponseDelegate(outcome: outcome)
        let session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
        let task = session.dataTask(with: request)
        let submission = SignMTSubmission(poses: poses) { [weak task] in task?.cancel() }
        task.resume()
        session.finishTasksAndInvalidate()
        return submission
    }

    /// Convenience for callers that already own the authorization decision.
    func translate(_ text: String) async throws -> ReceivedPose {
        try Task.checkCancellation()
        return try await startTranslation(text).response()
    }

    /// Encodes the complete caption without splitting or silently truncating it.
    static func makeRequest(text: String) throws(SignMTFailure) -> URLRequest {
        guard text.utf8.prefix(maximumTextBytes + 1).count <= maximumTextBytes else {
            throw SignMTFailure.requestTooLarge
        }
        guard text.contains(where: { !$0.isWhitespace }), text.prefix(281).count <= 280 else {
            throw SignMTFailure.invalidText
        }
        var components = URLComponents()
        components.scheme = "https"
        components.host = "us-central1-sign-mt.cloudfunctions.net"
        components.path = "/spoken_text_to_signed_pose"
        components.queryItems = [
            URLQueryItem(name: "spoken", value: "en"),
            URLQueryItem(name: "signed", value: "ase"),
            URLQueryItem(name: "text", value: text),
        ]
        // Some server query parsers interpret a literal plus as a space.
        components.percentEncodedQuery = components.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        guard let url = components.url, url.absoluteString.utf8.count <= maximumURLBytes else {
            throw SignMTFailure.requestTooLarge
        }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: timeout)
        request.httpMethod = "GET"
        request.setValue("application/pose", forHTTPHeaderField: "Accept")
        return request
    }

    /// Validates status, content type and any declared length before reading a body.
    static func validate(_ response: URLResponse) throws(SignMTFailure) {
        guard let http = response as? HTTPURLResponse else { throw SignMTFailure.invalidResponse }
        switch http.statusCode {
        case 200: break
        case 300...399: throw SignMTFailure.redirectRejected
        case 401, 403: throw SignMTFailure.unauthorized
        case 429:
            throw SignMTFailure.rateLimited(retryAfter: RetryAfter(http.value(forHTTPHeaderField: "Retry-After")))
        case 500...599: throw SignMTFailure.unavailable
        default: throw SignMTFailure.unexpectedStatus(http.statusCode)
        }
        guard http.mimeType?.lowercased() == "application/pose", http.expectedContentLength != 0 else {
            throw SignMTFailure.invalidResponse
        }
        guard http.expectedContentLength <= Int64(maximumResponseBytes) else {
            throw SignMTFailure.responseTooLarge
        }
    }
}
