import Testing
@testable import GymFlow

@MainActor
struct WorkoutValuePickerTests {
    @Test("Weight picker provides half-kilogram decimal values")
    func decimalWeightValues() {
        let transaction = WorkoutValuePickerTransaction(weight: 70)

        #expect(transaction.weightOptions.first == 0)
        #expect(transaction.weightOptions.last == 500)
        #expect(transaction.weightOptions.contains(20))
        #expect(transaction.weightOptions.contains(22.5))
        #expect(transaction.weightOptions.contains(27.5))
        #expect(transaction.weightOptions.contains(72.5))
    }

    @Test("Repetition picker provides integer values from zero through one hundred")
    func integerRepetitionValues() {
        let transaction = WorkoutValuePickerTransaction(repetitions: 8)

        #expect(transaction.repetitionOptions == Array(0 ... 100))
        #expect(transaction.selectedValue == .repetitions(8))
    }

    @Test("Cancelling a picker transaction leaves the set unchanged")
    func cancelDoesNotPersist() {
        let set = WorkoutSetRecord(setNumber: 1, weight: 70, repetitions: 8)
        var transaction = WorkoutValuePickerTransaction(weight: set.weight)

        transaction.selectWeight(72.5)
        transaction.cancel()
        transaction.commit(to: set)

        #expect(set.weight == 70)
        #expect(set.repetitions == 8)
    }

    @Test("Confirming picker transactions applies decimal weight and integer repetitions")
    func donePersists() {
        let set = WorkoutSetRecord(setNumber: 1, weight: 70, repetitions: 8)
        var weight = WorkoutValuePickerTransaction(weight: set.weight)
        var repetitions = WorkoutValuePickerTransaction(repetitions: set.repetitions)

        weight.selectWeight(72.5)
        weight.commit(to: set)
        repetitions.selectRepetitions(10)
        repetitions.commit(to: set)

        #expect(set.weight == 72.5)
        #expect(set.repetitions == 10)
    }

    @Test("Picker transactions open on the existing set value")
    func existingValueIsSelected() {
        let customWeight = WorkoutValuePickerTransaction(weight: 71.25)
        let repetitions = WorkoutValuePickerTransaction(repetitions: 12)

        #expect(customWeight.selectedValue == .weight(71.25))
        #expect(customWeight.weightOptions.contains(71.25))
        #expect(repetitions.selectedValue == .repetitions(12))
    }
}
