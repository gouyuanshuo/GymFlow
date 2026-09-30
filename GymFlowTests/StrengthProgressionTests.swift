import Foundation
import Testing
@testable import GymFlow

@Suite("Strength progression metrics")
struct StrengthProgressionTests {
    @Test("Best weight includes sets that are not the session's best e1RM")
    func bestWeightUsesEverySet() {
        let sets = [
            StrengthSetMetrics(weight: 100, repetitions: 1),
            StrengthSetMetrics(weight: 90, repetitions: 10),
        ]

        #expect(StrengthProgressionMetrics.bestWeight(in: sets) == 100)
        #expect(StrengthProgressionMetrics.strongestSet(in: sets)?.weight == 90)
    }

    @Test("Unsupported high repetitions do not inflate estimated one-rep max")
    func highRepetitionSelection() throws {
        let highRepetition = StrengthSetMetrics(weight: 200, repetitions: 16)
        let validSet = StrengthSetMetrics(weight: 70, repetitions: 5)
        let validEstimate = try #require(validSet.estimatedOneRepMax)

        #expect(highRepetition.estimatedOneRepMax == nil)
        #expect(abs(validEstimate - 81.666_666_666_7) < 0.000_01)
        #expect(
            StrengthProgressionMetrics.strongestSet(in: [highRepetition, validSet]) == validSet
        )
        #expect(StrengthProgressionMetrics.strongestSet(in: [highRepetition]) == nil)
    }

    @Test("Strength chart points require a canonical estimated one-rep max")
    func chartPointValidation() throws {
        let date = Date(timeIntervalSince1970: 100)
        let validPoint = try #require(
            StrengthDataPoint(date: date, weight: 70, repetitions: 5)
        )
        let invalidPoint: StrengthDataPoint? = StrengthDataPoint(
            date: date,
            weight: 200,
            repetitions: 16
        )

        #expect(abs(validPoint.estimated1RM - 81.666_666_666_7) < 0.000_01)
        #expect(invalidPoint == nil)
    }
}
