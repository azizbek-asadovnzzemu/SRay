import Foundation
import Testing
@testable import CaptionMetrics

struct CaptionBenchmarkTests {
    @Test func reportsCorpusWeightedAccuracyAndFailedRecognition() throws {
        // Arrange
        let input = try decode("""
        {
          "utterances": [
            {"reference": ["wait", "outside"], "hypothesis": ["wait", "inside"]},
            {"reference": ["turn", "left"], "hypothesis": null},
            {"reference": ["please"], "hypothesis": ["please", "now"]}
          ],
          "wordObservations": []
        }
        """)

        // Act
        let report = try CaptionBenchmark.score(input)

        // Assert
        #expect(report.referenceWords == 5)
        #expect(report.substitutions == 1)
        #expect(report.deletions == 2)
        #expect(report.insertions == 1)
        #expect(report.recognitionFailures == 1)
        #expect(report.wordErrorRate == 0.8)
    }

    @Test func preservesAccuracyAboveOneHundredPercent() throws {
        // Arrange
        let input = try decode("""
        {"utterances":[{"reference":["yes"],"hypothesis":["no","no","no"]}],"wordObservations":[]}
        """)

        // Act
        let report = try CaptionBenchmark.score(input)

        // Assert
        #expect(report.wordErrorRate == 3)
    }

    @Test func missingPartialsRemainInAllWordPercentile() throws {
        // Arrange
        let input = try decode("""
        {"utterances":[],"wordObservations":[
          {"spokenWordEndMilliseconds":400,"firstVisiblePartialMilliseconds":450},
          {"spokenWordEndMilliseconds":500,"firstVisiblePartialMilliseconds":null}
        ]}
        """)

        // Act
        let report = try CaptionBenchmark.score(input)

        // Assert
        #expect(report.observedWords == 2)
        #expect(report.missingPartials == 1)
        #expect(report.allWordP95Milliseconds == nil)
        #expect(report.displayedWordP95Milliseconds == 50)
        #expect(report.wordErrorRate == nil)
    }

    @Test func distanceUsesNearestRank() throws {
        // Arrange
        let observations = (1...20).map {
            CaptionBenchmarkInput.WordObservation(spokenWordEndMilliseconds: 100,
                                                  firstVisiblePartialMilliseconds: 100 + 10 * $0)
        }
        let input = CaptionBenchmarkInput(utterances: [], wordObservations: observations)

        // Act
        let report = try CaptionBenchmark.score(input)

        // Assert
        #expect(report.allWordP95Milliseconds == 190)
        #expect(report.displayedWordP95Milliseconds == 190)
    }

    @Test func preservesNegativeLatencyWhenTheCorrectPartialAppearsEarly() throws {
        // Arrange
        let input = try decode("""
        {"utterances":[],"wordObservations":[
          {"spokenWordEndMilliseconds":10,"firstVisiblePartialMilliseconds":9}
        ]}
        """)

        // Act
        let report = try CaptionBenchmark.score(input)

        // Assert
        #expect(report.allWordP95Milliseconds == -1)
        #expect(report.displayedWordP95Milliseconds == -1)
        #expect(report.missingPartials == 0)
    }

    @Test(arguments: [(-1, 0), (0, -1)])
    func refusesTimestampsBeforeTheClockOrigin(end: Int, visible: Int) {
        let observation = CaptionBenchmarkInput.WordObservation(
            spokenWordEndMilliseconds: end, firstVisiblePartialMilliseconds: visible
        )
        let input = CaptionBenchmarkInput(utterances: [], wordObservations: [observation])
        #expect(throws: CaptionBenchmarkError.invalidTiming) { try CaptionBenchmark.score(input) }
    }

    @Test func rejectsUntokenizedInput() throws {
        // Arrange
        let input = try decode("""
        {"utterances":[{"reference":["two words"],"hypothesis":null}],"wordObservations":[]}
        """)

        // Act and assert
        #expect(throws: CaptionBenchmarkError.invalidTokens) { try CaptionBenchmark.score(input) }
    }

    private func decode(_ json: String) throws -> CaptionBenchmarkInput {
        try JSONDecoder().decode(CaptionBenchmarkInput.self, from: Data(json.utf8))
    }
}
