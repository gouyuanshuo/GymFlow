import Foundation
import Testing
@testable import GymFlow

@Suite("PlateCalculatorTests")
struct PlateCalculatorTests {
    @Test("Target equal to or less than bar weight returns zero plates")
    func testZeroPlatesWhenUnderBarWeight() {
        let result = PlateCalculator.calculate(targetWeight: 20.0, barWeight: 20.0)
        #expect(result.platesPerSide.isEmpty)
        #expect(result.loadedSequence.isEmpty)
        #expect(result.loadedTotal == 20.0)
        #expect(result.remainder == 0.0)

        let underResult = PlateCalculator.calculate(targetWeight: 15.0, barWeight: 20.0)
        #expect(underResult.platesPerSide.isEmpty)
        #expect(underResult.loadedTotal == 20.0)
    }

    @Test("Standard 100kg calculation loads 40kg per side")
    func testStandardOneHundredKilograms() {
        let result = PlateCalculator.calculate(targetWeight: 100.0, barWeight: 20.0)
        #expect(result.weightPerSide == 40.0)
        #expect(result.loadedTotal == 100.0)
        #expect(result.remainder == 0.0)

        // 40kg per side greedy: 25kg + 15kg
        let totalLoadedPerSide = result.loadedSequence.reduce(0.0) { $0 + $1.weight }
        #expect(totalLoadedPerSide == 40.0)
    }

    @Test("Fractional weight 142.5kg loads exact plates")
    func testFractionalWeight() {
        let result = PlateCalculator.calculate(targetWeight: 142.5, barWeight: 20.0)
        #expect(result.weightPerSide == 61.25)
        #expect(result.loadedTotal == 142.5)
        #expect(result.remainder == 0.0)

        // 61.25kg per side: 25 + 25 + 10 + 1.25
        let weights = result.loadedSequence.map(\.weight)
        #expect(weights == [25.0, 25.0, 10.0, 1.25])
    }

    @Test("Women's 15kg bar distributes correctly")
    func testFifteenKilogramBar() {
        let result = PlateCalculator.calculate(targetWeight: 65.0, barWeight: 15.0)
        #expect(result.weightPerSide == 25.0)
        #expect(result.loadedTotal == 65.0)
        #expect(result.remainder == 0.0)
        #expect(result.loadedSequence.map(\.weight) == [25.0])
    }
}
