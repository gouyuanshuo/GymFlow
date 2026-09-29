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
    func highRepetitionSelection() {
        let highRepetition = StrengthSetMetrics(weight: 50, repetitions: 40)
        let validSet = StrengthSetMetrics(weight: 70, repetitions: 5)

        #expect(highRepetition.estimatedOneRepMax == 50)
        #expect(abs(validSet.estimatedOneRepMax - 81.666_666_666_7) < 0.000_01)
        #expect(
            StrengthProgressionMetrics.strongestSet(in: [highRepetition, validSet]) == validSet
        )
    }
}
