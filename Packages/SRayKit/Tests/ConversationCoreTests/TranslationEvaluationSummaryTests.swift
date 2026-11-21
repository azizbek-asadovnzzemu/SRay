import Testing
@testable import ConversationCore

struct TranslationEvaluationSummaryTests {
    @Test func percentileUsesSuccessfulHandoffsAndRoundsUp() {
        var summary = TranslationEvaluationSummary()
        summary.recordOmission(.expired)
        #expect(summary.rendererHandoffP95UpperBound == nil)

        for _ in 0..<19 { summary.recordHandoff(after: .milliseconds(501)) }
        summary.recordHandoff(after: .seconds(9))
        #expect(summary.rendererHandoffP95UpperBound == .milliseconds(600))
        #expect(summary.rendererHandoffs == 20)
        #expect(summary.omissions == [.expired: 1])

        summary.recordHandoff(after: .seconds(9))
        #expect(summary.rendererHandoffP95UpperBound == .seconds(9))
    }

    @Test(arguments: [Duration.zero, .milliseconds(100), .seconds(9) + .milliseconds(900)])
    func exactBinBoundaryIsPreserved(latency: Duration) {
        var summary = TranslationEvaluationSummary()
        summary.recordHandoff(after: latency)
        #expect(summary.rendererHandoffP95UpperBound == latency)
    }
}
