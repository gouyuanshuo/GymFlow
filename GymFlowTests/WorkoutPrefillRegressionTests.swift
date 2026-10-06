import Foundation
import Testing

@testable import GymFlow

@MainActor
struct WorkoutPrefillRegressionTests {
    @Test("Prefill resolves all planned sets from their newest usable history")
    func multipleSetsAndOlderFallback() {
        let id = UUID()
        let plan = planFor(id: id, name: "Renamed Bench", setCount: 3)
        let older = session(
            day: 1,
            records: [record(id: id, name: "Old Bench", weights: [50, 55, 60])]
        )
        let newer = session(
            day: 2,
            records: [
                ExerciseRecord(
                    exerciseID: id,
                    exerciseNameSnapshot: "Old Bench",
                    sets: [
                        WorkoutSetRecord(setNumber: 1, weight: 70, repetitions: 5),
                        WorkoutSetRecord(
                            setNumber: 2, weight: 75, repetitions: 5, isCompleted: true
                        ),
                    ]
                )
            ]
        )

        let result = WorkoutService.makeSession(
            from: plan, previousSessions: [older, newer]
        ).orderedExerciseRecords[0].orderedSets

        #expect(result.map(\.weight) == [50, 75, 60])
        #expect(result.map(\.repetitions) == [8, 5, 8])
    }

    @Test("Prefill prefers the later matching record within one session")
    func duplicateRecords() {
        let id = UUID()
        let plan = planFor(id: id, name: "Bench", setCount: 2)
        let historical = session(
            day: 1,
            records: [
                record(id: id, name: "Bench", weights: [50, 55], sortOrder: 0),
                record(id: id, name: "Bench", weights: [70, 75], sortOrder: 1),
            ])

        let result = WorkoutService.makeSession(
            from: plan, previousSessions: [historical]
        ).orderedExerciseRecords[0].orderedSets

        #expect(result.map(\.weight) == [70, 75])
    }

    @Test("Prefill uses legacy names only for ID-less records")
    func legacyFallbackAndNoMatch() {
        let id = UUID()
        let otherID = UUID()
        let plan = planFor(id: id, name: "Bench Press", setCount: 2)
        let historical = session(
            day: 1,
            records: [
                record(id: nil, name: "  BENCH  PRESS ", weights: [65]),
                record(id: otherID, name: "Bench Press", weights: [100], sortOrder: 1),
            ])

        let result = WorkoutService.makeSession(
            from: plan, previousSessions: [historical]
        ).orderedExerciseRecords[0].orderedSets
        let absent = WorkoutService.makeSession(
            from: planFor(id: UUID(), name: "No History", setCount: 2),
            previousSessions: [historical]
        ).orderedExerciseRecords[0].orderedSets

        #expect(result.map(\.weight) == [65, 40])
        #expect(absent.map(\.weight) == [40, 40])
    }

    private func planFor(id: UUID, name: String, setCount: Int) -> WorkoutPlan {
        WorkoutPlan(
            name: "Test",
            exercises: [
                PlannedExercise(
                    exerciseID: id,
                    exerciseNameSnapshot: name,
                    targetSets: setCount,
                    targetRepetitions: 8,
                    targetWeight: 40
                )
            ])
    }

    private func session(day: Int, records: [ExerciseRecord]) -> WorkoutSession {
        WorkoutSession(
            planNameSnapshot: "History",
            startedAt: Date(timeIntervalSince1970: Double(day) * 86_400),
            status: .completed,
            exerciseRecords: records
        )
    }

    private func record(
        id: UUID?, name: String, weights: [Double], sortOrder: Int = 0
    ) -> ExerciseRecord {
        ExerciseRecord(
            exerciseID: id,
            exerciseNameSnapshot: name,
            sortOrder: sortOrder,
            sets: weights.enumerated().map { offset, weight in
                WorkoutSetRecord(
                    setNumber: offset + 1, weight: weight,
                    repetitions: 8, isCompleted: true
                )
            }
        )
    }
}
