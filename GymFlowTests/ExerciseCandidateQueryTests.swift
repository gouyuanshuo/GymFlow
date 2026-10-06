import Foundation
import SwiftData
import Testing

@testable import GymFlow

@MainActor
struct ExerciseCandidateQueryTests {
    @Test("Exercise candidate query preserves stable IDs and legacy fallback")
    func candidatesRemainConservative() throws {
        let schema = Schema([
            ExerciseDefinition.self, WorkoutPlan.self, PlannedExercise.self,
            WorkoutSession.self, ExerciseRecord.self, WorkoutSetRecord.self,
            ImportedTrack.self, Playlist.self, PlaylistTrack.self,
        ])
        let configuration = ModelConfiguration(
            "ExerciseCandidateQueryTests", schema: schema,
            isStoredInMemoryOnly: true, cloudKitDatabase: .none
        )
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)
        let exerciseID = UUID()
        let unrelatedID = UUID()
        let renamed = session(
            id: exerciseID, name: "Old Name", status: .completed, day: 1
        )
        let legacy = session(
            id: nil, name: "  BENCH  PRESS ", status: .completed, day: 2
        )
        let unrelated = session(
            id: unrelatedID, name: "Bench Press", status: .completed, day: 3
        )
        let active = session(
            id: exerciseID, name: "Bench Press", status: .active, day: 4
        )
        for item in [renamed, legacy, unrelated, active] { context.insert(item) }
        try context.save()

        let candidates = try context.fetch(
            FetchDescriptor(
                predicate: WorkoutSession.predicate(candidatesForExerciseID: exerciseID)
            ))
        let candidateIDs = Set(candidates.map(\.id))
        let summary = ExercisePerformanceService.summary(
            exerciseID: exerciseID, exerciseName: "Bench Press",
            sessions: candidates
        )

        #expect(candidateIDs == Set([renamed.id, legacy.id, active.id]))
        #expect(summary.heaviestWeightRecord?.weight == 80)
        #expect(summary.personalBestEvents.count == 2)
    }

    private func session(
        id: UUID?, name: String, status: WorkoutSessionStatus, day: Int
    ) -> WorkoutSession {
        let started = Date(timeIntervalSince1970: Double(day) * 86_400)
        return WorkoutSession(
            planNameSnapshot: "Query test",
            startedAt: started,
            completedAt: started.addingTimeInterval(3_600),
            status: status,
            exerciseRecords: [
                ExerciseRecord(
                    exerciseID: id,
                    exerciseNameSnapshot: name,
                    sets: [
                        WorkoutSetRecord(
                            setNumber: 1,
                            weight: day == 2 ? 80 : 70,
                            repetitions: 8,
                            isCompleted: true
                        )
                    ]
                )
            ]
        )
    }
}
