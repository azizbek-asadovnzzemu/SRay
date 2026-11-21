import Foundation
import Testing
@testable import SignMT

/// Checks the observed network contract using only synthetic URLs, headers and bytes.
struct SignMTClientTests {
    /// Reserved query characters and non-ASCII text survive request construction.
    @Test func encodesWholeEnglishUtterance() throws {
        // Arrange
        let text = "Do not send A+B & Café 🚲?"

        // Act
        let request = try SignMTClient.makeRequest(text: text)
        let url = try #require(request.url)
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))

        // Assert
        #expect(request.httpMethod == "GET")
        #expect(url.scheme == "https")
        #expect(url.host == "us-central1-sign-mt.cloudfunctions.net")
        #expect(url.path == "/spoken_text_to_signed_pose")
        #expect(components.queryItems == [
            .init(name: "spoken", value: "en"), .init(name: "signed", value: "ase"),
            .init(name: "text", value: text),
        ])
        #expect(components.percentEncodedQuery?.contains("%2B") == true)
        #expect(request.cachePolicy == .reloadIgnoringLocalCacheData)
        #expect(request.timeoutInterval == 15)
    }

    /// Inputs outside the local envelope are rejected before building a URL.
    @Test(arguments: [
        (" \n", SignMTFailure.invalidText),
        (String(repeating: "x", count: 281), .invalidText),

    ])
    func rejectsInvalidInput(text: String, error: SignMTFailure) {
        // Arrange and act
        #expect(throws: error) { try SignMTClient.makeRequest(text: text) }
    }

    /// A single grapheme can exceed the byte envelope and must be rejected.
    @Test func rejectsOversizedGrapheme() {
        // Arrange
        let text = "a" + String(repeating: "\u{0301}", count: 2_048)

        // Act and assert
        #expect(throws: SignMTFailure.requestTooLarge) { try SignMTClient.makeRequest(text: text) }
    }

    /// Non-success statuses map to typed failures before any response body is collected.
    @Test(arguments: [
        (302, SignMTFailure.redirectRejected),
        (401, .unauthorized),
        (403, .unauthorized),
        (429, .rateLimited(retryAfter: .delay(.seconds(17)))),
        (500, .unavailable),
        (418, .unexpectedStatus(418)),
    ])
    func mapsStatus(code: Int, error: SignMTFailure) throws {
        // Arrange
        let response = try makeResponse(code: code, headers: ["Retry-After": "17"])
        // Act and assert
        #expect(throws: error) { try SignMTClient.validate(response) }
    }

    /// Retry-After accepts a GMT server date and ignores an invalid value.
    @Test func parsesRetryDate() {
        // Arrange
        let header = "Sun, 06 Nov 1994 08:49:37 GMT"

        // Act
        let parsed = RetryAfter(header)

        // Assert
        #expect(parsed == .date(Date(timeIntervalSince1970: 784_111_777)))
        #expect(RetryAfter("invalid") == nil)
    }

    @Test func convertsRateLimitAdviceUsingTheSuppliedWallClock() {
        let date = Date(timeIntervalSince1970: 784_111_777)
        let datedLimit = SignMTFailure.rateLimited(retryAfter: .date(date.addingTimeInterval(2.5)))

        #expect(datedLimit.retryDelay(relativeTo: date) == .milliseconds(2_500))
        #expect(datedLimit.retryDelay(relativeTo: date.addingTimeInterval(3)) == .zero)
        #expect(SignMTFailure.rateLimited(retryAfter: .delay(.seconds(17))).retryDelay(relativeTo: date) == .seconds(17))
        #expect(SignMTFailure.rateLimited(retryAfter: nil).retryDelay(relativeTo: date) == nil)
        #expect(SignMTFailure.unavailable.retryDelay(relativeTo: date) == nil)
    }

    /// Header validation rejects a non-pose response or declared oversize body.
    @Test func validatesMediaTypeAndDeclaredLength() throws {
        // Arrange
        let pose = try makeResponse(code: 200, headers: ["Content-Type": "application/pose"])
        let html = try makeResponse(code: 200, headers: ["Content-Type": "text/html"])
        let oversize = try makeResponse(code: 200, headers: [
            "Content-Type": "application/pose",
            "Content-Length": String(SignMTClient.maximumResponseBytes + 1),
        ])

        // Act and assert
        #expect(throws: Never.self) { try SignMTClient.validate(pose) }
        #expect(throws: SignMTFailure.invalidResponse) { try SignMTClient.validate(html) }
        #expect(throws: SignMTFailure.responseTooLarge) { try SignMTClient.validate(oversize) }
    }

    private func makeResponse(code: Int, headers: [String: String]) throws -> HTTPURLResponse {
        let url = try #require(URL(string: "https://example.invalid"))
        return try #require(HTTPURLResponse(url: url, statusCode: code, httpVersion: "HTTP/1.1", headerFields: headers))
    }
}
