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

    private let session: URLSession

    /// Creates an ephemeral client with no request cache, cookies or stored credentials.
    init() {
        let config = URLSessionConfiguration.ephemeral
        config.urlCache = nil
        config.httpCookieStorage = nil
        config.httpShouldSetCookies = false
        config.urlCredentialStorage = nil
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.timeoutIntervalForRequest = Self.timeout
        config.timeoutIntervalForResource = Self.timeout
        config.waitsForConnectivity = false
        session = URLSession(configuration: config)
    }

    deinit {
        session.invalidateAndCancel()
    }

    /// Sends a single explicitly authorized request, with cancellation and no redirects.
    /// - Throws: CancellationError or a content-free SignMTFailure.
    func translate(_ text: String) async throws -> ReceivedPose {
        let request = try Self.makeRequest(text: text)
        do {
            try Task.checkCancellation()
            let (bytes, response) = try await session.bytes(for: request, delegate: RejectRedirects())
            defer { bytes.task.cancel() }
            try Self.validate(response)
            return try await Self.readPose(from: bytes)
        } catch is CancellationError {
            throw CancellationError()
        } catch let failure as SignMTFailure {
            throw failure
        } catch let error as URLError {
            switch error.code {
            case .cancelled: throw CancellationError()
            case .notConnectedToInternet, .networkConnectionLost: throw SignMTFailure.offline
            case .timedOut: throw SignMTFailure.timedOut
            default: throw SignMTFailure.unavailable
            }
        } catch {
            throw SignMTFailure.unavailable
        }
    }

    /// Encodes the complete caption without splitting or silently truncating it.
    static func makeRequest(text: String) throws -> URLRequest {
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
    static func validate(_ response: URLResponse) throws {
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

    /// Reads at most the given limit even if Content-Length is absent or incorrect.
    static func readPose<Bytes: AsyncSequence>(
        from bytes: Bytes, limit: Int = maximumResponseBytes
    ) async throws -> ReceivedPose where Bytes.Element == UInt8 {
        var data = Data()
        for try await byte in bytes {
            guard data.count < limit else { throw SignMTFailure.responseTooLarge }
            if data.count.isMultiple(of: 4_096) { try Task.checkCancellation() }
            data.append(byte)
        }
        try Task.checkCancellation()
        guard !data.isEmpty else { throw SignMTFailure.invalidResponse }
        return ReceivedPose(bytes: data)
    }

    /// Prevents the transcript-bearing query from following any server redirect.
    private final class RejectRedirects: NSObject, URLSessionTaskDelegate {
        func urlSession(
            _ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
            newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void
        ) {
            completionHandler(nil)
        }
    }
}
