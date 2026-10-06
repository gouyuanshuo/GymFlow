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

    @Test("Recent detail history includes completed sets from later duplicate entries")
    func recentDetailHistoryUsesAllMatchingRecords() {
        let exerciseID = UUID()
        let completed = WorkoutSetRecord(
            setNumber: 1, weight: 75, repetitions: 8, isCompleted: true
        )
        let session = WorkoutSession(
            planNameSnapshot: "Duplicate bench",
            status: .completed,
            exerciseRecords: [
                ExerciseRecord(
                    exerciseID: exerciseID, exerciseNameSnapshot: "Old bench",
                    sortOrder: 0, sets: [WorkoutSetRecord(setNumber: 1)]
                ),
                ExerciseRecord(
                    exerciseID: exerciseID, exerciseNameSnapshot: "Old bench",
                    sortOrder: 1, sets: [completed]
                ),
            ]
        )

        let recent = ExerciseProgressHistory.recentCompletedSessions(
            matching: ExerciseIdentity(id: exerciseID, name: "Renamed bench"),
            in: [session], limit: 8
        )

        #expect(recent.map(\.session.id) == [session.id])
        #expect(recent.first?.completedSets.map(\.id) == [completed.id])
    }

    @Test("Recent detail history keeps legacy fallback and ignores only-incomplete entries")
    func recentDetailHistoryLegacyAndIncomplete() {
        let exerciseID = UUID()
        let legacySet = WorkoutSetRecord(setNumber: 1, weight: 60, repetitions: 10, isCompleted: true)
        let legacy = WorkoutSession(
            planNameSnapshot: "Legacy",
            status: .completed,
            exerciseRecords: [
                ExerciseRecord(exerciseNameSnapshot: " BENCH  PRESS ", sets: [legacySet])
            ]
        )
        let incomplete = WorkoutSession(
            planNameSnapshot: "Incomplete",
            status: .completed,
            exerciseRecords: [
                ExerciseRecord(
                    exerciseID: exerciseID, exerciseNameSnapshot: "Bench Press",
                    sets: [WorkoutSetRecord(setNumber: 1)]
                )
            ]
        )

        let recent = ExerciseProgressHistory.recentCompletedSessions(
            matching: ExerciseIdentity(id: exerciseID, name: "Bench Press"),
            in: [incomplete, legacy], limit: 8
        )

        #expect(recent.map(\.session.id) == [legacy.id])
        #expect(recent.first?.completedSets.map(\.id) == [legacySet.id])
    }
}
