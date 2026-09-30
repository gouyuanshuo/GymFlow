import Foundation
import Testing
@testable import GymFlow

@Suite("Exercise progress history")
struct ExerciseProgressHistoryTests {
    @Test("Repeated exercise records in one workout all contribute completed sets")
    func repeatedExerciseRecords() {
        let exerciseID = UUID()
        let firstSet = WorkoutSetRecord(
            setNumber: 1, weight: 90, repetitions: 10, isCompleted: true
        )
        let secondSet = WorkoutSetRecord(
            setNumber: 1, weight: 100, repetitions: 1, isCompleted: true
        )
        let incompleteSet = WorkoutSetRecord(setNumber: 2, weight: 120, repetitions: 1)
        let otherSet = WorkoutSetRecord(
            setNumber: 1, weight: 200, repetitions: 1, isCompleted: true
        )
        let legacySet = WorkoutSetRecord(
            setNumber: 1, weight: 80, repetitions: 8, isCompleted: true
        )
        let session = WorkoutSession(
            planNameSnapshot: "Repeated Bench",
            status: .completed,
            exerciseRecords: [
                ExerciseRecord(
                    exerciseID: exerciseID, exerciseNameSnapshot: "Bench Press",
                    sortOrder: 0, sets: [firstSet]
                ),
                ExerciseRecord(
                    exerciseID: UUID(), exerciseNameSnapshot: "Bench Press",
                    sortOrder: 1, sets: [otherSet]
                ),
                ExerciseRecord(
                    exerciseID: exerciseID, exerciseNameSnapshot: "Bench Press", sortOrder: 2,
                    sets: [secondSet, incompleteSet]
                ),
                ExerciseRecord(
                    exerciseNameSnapshot: "Bench Press", sortOrder: 3, sets: [legacySet]
                ),
            ]
        )

        let sets = ExerciseProgressHistory.completedSets(
            matching: ExerciseIdentity(id: exerciseID, name: "Bench Press"), in: session
        )
        #expect(sets.map(\.id) == [firstSet.id, secondSet.id, legacySet.id])
        #expect(sets.map(\.weight).max() == 100)
    }

    @Test("Strength progress excludes warm-up and incomplete sets")
    func completedWorkingSetsOnly() {
        let exerciseID = UUID()
        let workingSet = WorkoutSetRecord(
            setNumber: 1,
            weight: 70,
            repetitions: 8,
            isCompleted: true
        )
        let warmupSet = WorkoutSetRecord(
            setNumber: 2,
            weight: 100,
            repetitions: 5,
            isCompleted: true,
            isWarmup: true
        )
        let incompleteSet = WorkoutSetRecord(
            setNumber: 3,
            weight: 120,
            repetitions: 5
        )
        let session = WorkoutSession(
            planNameSnapshot: "Progress",
            status: .completed,
            exerciseRecords: [
                ExerciseRecord(
                    exerciseID: exerciseID,
                    exerciseNameSnapshot: "Bench Press",
                    sets: [workingSet, warmupSet, incompleteSet]
                )
            ]
        )

        let sets = ExerciseProgressHistory.completedWorkingSets(
            matching: ExerciseIdentity(id: exerciseID, name: "Bench Press"),
            in: session
        )

        #expect(sets.map(\.id) == [workingSet.id])
    }
}
