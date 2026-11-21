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

    @Test func countsTargetSuccessesAndRanksOmissionsLast() {
        var summary = TranslationEvaluationSummary()
        #expect(summary.resolvedEligibleUtterances == 0)
        #expect(summary.resolvedHandoffP95UpperBound == nil)

        for _ in 0..<18 { summary.recordHandoff(after: .seconds(5)) }
        summary.recordHandoff(after: .milliseconds(5_001))
        summary.recordOmission(.capacity)
        #expect(summary.resolvedEligibleUtterances == 20)
        #expect(summary.handoffsWithinFiveSeconds == 18)
        #expect(summary.resolvedHandoffP95UpperBound == .milliseconds(5_100))

        summary.recordOmission(.expired)
        #expect(summary.resolvedEligibleUtterances == 21)
        #expect(summary.handoffsWithinFiveSeconds == 18)
        #expect(summary.resolvedHandoffP95UpperBound == nil)
        #expect(summary.rendererHandoffP95UpperBound == .milliseconds(5_100))
    }

    @Test(arguments: [Duration.zero, .milliseconds(100), .seconds(9) + .milliseconds(900)])
    func exactBinBoundaryIsPreserved(latency: Duration) {
        var summary = TranslationEvaluationSummary()
        summary.recordHandoff(after: latency)
        #expect(summary.rendererHandoffP95UpperBound == latency)
    }
}
