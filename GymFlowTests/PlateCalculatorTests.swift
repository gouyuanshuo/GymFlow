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
        #expect(underResult.targetWeight == 20.0)
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

    @Test("Exact load beats a greedy plate choice")
    func testExactTwentyFourKilograms() {
        let result = PlateCalculator.calculate(targetWeight: 24.0, barWeight: 20.0)

        #expect(result.loadedSequence.map(\.weight) == [0.5, 0.5, 0.5, 0.5])
        #expect(result.weightPerSide == 2.0)
        #expect(result.loadedTotal == 24.0)
        #expect(result.remainder == 0.0)
    }

    @Test("Large exact targets do not fall back to a greedy remainder")
    func testLargeExactTarget() {
        let result = PlateCalculator.calculate(targetWeight: 2_024.0, barWeight: 20.0)

        #expect(result.loadedTotal == 2_024.0)
        #expect(result.remainder == 0.0)
        #expect(result.loadedSequence.count == 44)
        #expect(result.loadedSequence.suffix(4).map(\.weight) == [0.5, 0.5, 0.5, 0.5])
    }

    @Test("Plate labels preserve significant hundredths")
    func testStandardPlateLabels() {
        #expect(
            OlympicPlate.available.map(\.displayName)
                == ["25", "20", "15", "10", "5", "2.5", "1.25", "0.5"]
        )
    }

    @Test("The plate display keeps quarter-kilogram values")
    func testPrecisePlateWeightDisplay() {
        let exact = PlateCalculator.calculate(targetWeight: 22.5, barWeight: 20)
        let remainder = PlateCalculator.calculate(targetWeight: 22.75, barWeight: 20)

        #expect(exact.weightPerSide == 1.25)
        #expect(GymFlowFormatters.plateWeight(exact.weightPerSide) == "1.25")
        #expect(remainder.remainder == 0.25)
        #expect(GymFlowFormatters.plateWeight(remainder.remainder) == "0.25")
    }

    @Test("The calculator never loads more than the target")
    func testNearQuarterUnitDoesNotOvershoot() {
        let target = 20.999_999_999_5
        let result = PlateCalculator.calculate(targetWeight: target, barWeight: 20)

        #expect(result.loadedTotal <= target)
        #expect(result.loadedSequence.isEmpty)
    }

    @Test("Targets outside the calculator range do not allocate plate sequences")
    func testUnsupportedTarget() {
        for target in [10_001.0, 1_000_000_000.0, .infinity, .nan] {
            let result = PlateCalculator.calculate(targetWeight: target, barWeight: 20)
            #expect(!result.isSupported)
            #expect(result.loadedSequence.isEmpty)
            #expect(result.loadedTotal == 20)
        }
    }
}
