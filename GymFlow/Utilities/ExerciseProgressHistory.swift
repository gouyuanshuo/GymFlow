import Foundation

struct ExerciseRecentSession: Identifiable {
    let session: WorkoutSession
    let completedSets: [WorkoutSetRecord]

    var id: UUID { session.id }
}

/// Gathers every completed set for an exercise across repeated entries in one session.
enum ExerciseProgressHistory {
    static func completedSets(
        matching identity: ExerciseIdentity, in session: WorkoutSession
    ) -> [WorkoutSetRecord] {
        session.orderedExerciseRecords
            .filter(identity.matches)
            .flatMap { $0.orderedSets.filter(\.isCompleted) }
    }

    /// Completed non-warm-up sets eligible for strength metrics and e1RM progress.
    static func completedWorkingSets(
        matching identity: ExerciseIdentity,
        in session: WorkoutSession
    ) -> [WorkoutSetRecord] {
        completedSets(matching: identity, in: session).filter { !$0.isWarmup }
    }

    /// The most recent completed sessions that contain completed sets for an exercise.
    /// `sessions` must be newest first; duplicate exercise entries are gathered together.
    static func recentCompletedSessions(
        matching identity: ExerciseIdentity,
        in sessions: [WorkoutSession],
        limit: Int
    ) -> [ExerciseRecentSession] {
        guard limit > 0 else { return [] }
        var recent: [ExerciseRecentSession] = []
        for session in sessions where session.status == .completed {
            let sets = completedSets(matching: identity, in: session)
            guard !sets.isEmpty else { continue }
            recent.append(ExerciseRecentSession(session: session, completedSets: sets))
            if recent.count == limit { break }
        }
        return recent
    }
}
