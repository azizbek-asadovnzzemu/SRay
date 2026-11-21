import Foundation
import os
import Testing
@testable import SignMT

/// Exercises the real URLSession delegate path without giving the loader network access.
struct SignMTDeliveryTests {
    @Test func receivesTheResponseFromAnAlreadyStartedSubmission() async throws {
        let client = SignMTClient(protocolClass: SyntheticPoseProtocol.self)
        let submission = try client.startTranslation("split")
        let pose = try await submission.response()
        #expect(pose.bytes == Data([1, 2, 3, 4]))
    }

    @Test(arguments: [
        ("empty", SignMTFailure.invalidResponse),
        ("too large", .responseTooLarge),
        ("rate limit", .rateLimited(retryAfter: .delay(.seconds(17)))),
        ("timeout", .timedOut),
        ("offline", .offline),
    ])
    func reportsOnlyTypedFailures(scenario: String, expected: SignMTFailure) async throws {
        let client = SignMTClient(protocolClass: SyntheticPoseProtocol.self)
        let submission = try client.startTranslation(scenario)

        await #expect(throws: expected) { try await submission.response() }
    }

    @Test func cancelsBeforeAnAwaitAndNeverReturnsAPose() async throws {
        let client = SignMTClient(protocolClass: SyntheticPoseProtocol.self)
        let submission = try client.startTranslation("waiting")
        submission.cancel()
        submission.cancel()

        await #expect(throws: CancellationError.self) { try await submission.response() }
    }

    @Test func cancellationInvalidatesABufferedPoseAndCallsTheTransportOnce() async {
        let (poses, outcome) = AsyncThrowingStream<ReceivedPose, any Error>.makeStream()
        let cancellations = OSAllocatedUnfairLock(initialState: 0)
        let submission = SignMTSubmission(poses: poses) {
            cancellations.withLock { $0 += 1 }
        }
        outcome.yield(ReceivedPose(bytes: Data([1])))
        outcome.finish()

        submission.cancel()
        submission.cancel()

        #expect(cancellations.withLock { $0 } == 1)
        await #expect(throws: CancellationError.self) { try await submission.response() }
    }

    @Test func cancellingTheResponseTaskCancelsItsSubmission() async throws {
        let client = SignMTClient(protocolClass: SyntheticPoseProtocol.self)
        let submission = try client.startTranslation("waiting")
        let consumer = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await submission.response()
        }

        await #expect(throws: CancellationError.self) { try await consumer.value }
        await #expect(throws: CancellationError.self) { try await submission.response() }
    }
}

private final class SyntheticPoseProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url, let client else { return }
        let text = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first { $0.name == "text" }?.value
        if text == "waiting" { return }
        if text == "timeout" || text == "offline" {
            let code: URLError.Code = text == "timeout" ? .timedOut : .notConnectedToInternet
            client.urlProtocol(self, didFailWithError: URLError(code, userInfo: [NSURLErrorFailingURLErrorKey: url]))
            return
        }

        let status = text == "rate limit" ? 429 : 200
        guard let response = HTTPURLResponse(
            url: url, statusCode: status, httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/pose", "Retry-After": "17"]
        ) else { return }
        client.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)

        if text == "split" {
            client.urlProtocol(self, didLoad: Data([1, 2]))
            client.urlProtocol(self, didLoad: Data([3, 4]))
        } else if text == "too large" {
            client.urlProtocol(self, didLoad: Data(count: SignMTClient.maximumResponseBytes))
            client.urlProtocol(self, didLoad: Data([1]))
        }
        client.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
