import Foundation

enum WorkoutService {
    static func duplicate(plan: WorkoutPlan, name: String? = nil, now: Date = Date()) -> WorkoutPlan {
        let exercises = plan.orderedExercises.map { exercise in
            PlannedExercise(
                exerciseID: exercise.exerciseID,
                exerciseNameSnapshot: exercise.exerciseNameSnapshot,
                targetSets: exercise.targetSets,
                targetRepetitions: exercise.targetRepetitions,
                targetWeight: exercise.targetWeight,
                restSeconds: exercise.restSeconds,
                notes: exercise.notes,
                sortOrder: exercise.sortOrder
            )
        }
        return WorkoutPlan(
            name: name ?? "\(plan.name) Copy",
            notes: plan.notes,
            createdAt: now,
            updatedAt: now,
            sortOrder: plan.sortOrder + 1,
            assignedPlaylistID: plan.assignedPlaylistID,
            exercises: exercises
        )
    }

    static func makeSession(
        from plan: WorkoutPlan,
        previousSessions: [WorkoutSession] = [],
        playlist: Playlist? = nil,
        now: Date = Date()
    ) -> WorkoutSession {
        // All planned exercises share one completed-history ordering.
        let historyNewestFirst = previousSessions
            .filter { $0.status == .completed }
            .sorted { $0.startedAt > $1.startedAt }
        let records = plan.orderedExercises.map { exercise in
            let identity = ExerciseIdentity(
                id: exercise.exerciseID,
                name: exercise.exerciseNameSnapshot
            )
            let setCount = max(1, exercise.targetSets)
            let previousSets = latestCompletedSets(
                matching: identity,
                setCount: setCount,
                in: historyNewestFirst
            )
            let sets = (1...setCount).map { setNumber in
                let previousSet = previousSets[setNumber]
                return WorkoutSetRecord(
                    setNumber: setNumber,
                    weight: max(0, previousSet?.weight ?? exercise.targetWeight),
                    repetitions: max(0, previousSet?.repetitions ?? exercise.targetRepetitions)
                )
            }
            return ExerciseRecord(
                exerciseID: exercise.exerciseID,
                exerciseNameSnapshot: exercise.exerciseNameSnapshot,
                sortOrder: exercise.sortOrder,
                restSeconds: max(0, exercise.restSeconds),
                sets: sets,
                notes: exercise.notes
            )
        }
        return WorkoutSession(
            workoutPlanID: plan.id,
            planNameSnapshot: plan.name,
            startedAt: now,
            currentExerciseIndex: 0,
            currentSetNumber: 1,
            playlistID: playlist?.id,
            playlistNameSnapshot: playlist?.name,
            status: .active,
            exerciseRecords: records
        )
    }

    /// Resolves each target number once, preserving the latest usable set for that number.
    private static func latestCompletedSets(
        matching identity: ExerciseIdentity,
        setCount: Int,
        in sessionsNewestFirst: [WorkoutSession]
    ) -> [Int: WorkoutSetRecord] {
        var latestByNumber: [Int: WorkoutSetRecord] = [:]
        history: for session in sessionsNewestFirst {
            // If an exercise appears twice in one workout, the later entry represents the most
            // recent performance within that session.
            for record in session.orderedExerciseRecords.reversed() where identity.matches(record) {
                for set in record.orderedSets.reversed() {
                    guard (1...setCount).contains(set.setNumber),
                          latestByNumber[set.setNumber] == nil,
                          isUsablePrefillSet(set) else { continue }
                    latestByNumber[set.setNumber] = set
                    if latestByNumber.count == setCount { break history }
                }
            }
        }
        return latestByNumber
    }

    private static func isUsablePrefillSet(_ set: WorkoutSetRecord) -> Bool {
        set.isCompleted
            && !set.isWarmup
            && set.weight.isFinite
            && set.weight >= 0
            && set.repetitions > 0
    }
}
