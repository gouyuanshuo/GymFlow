import Foundation

/// Gathers every completed set for an exercise across repeated entries in one session.
enum ExerciseProgressHistory {
    static func completedSets(
        matching identity: ExerciseIdentity, in session: WorkoutSession
    ) -> [WorkoutSetRecord] {
        session.orderedExerciseRecords
            .filter(identity.matches)
            .flatMap { $0.orderedSets.filter(\.isCompleted) }
    }
}
