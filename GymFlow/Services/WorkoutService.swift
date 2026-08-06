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
        let records = plan.orderedExercises.map { exercise in
            let previousRecord = latestRecord(for: exercise, in: previousSessions)
            let sets = (1...max(1, exercise.targetSets)).map { setNumber in
                let previousSet = previousRecord?.orderedSets.first(where: {
                    $0.setNumber == setNumber && $0.isCompleted
                })
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

    private static func latestRecord(
        for exercise: PlannedExercise,
        in sessions: [WorkoutSession]
    ) -> ExerciseRecord? {
        sessions
            .filter { $0.status == .completed }
            .sorted { $0.startedAt > $1.startedAt }
            .lazy
            .compactMap { session in
                session.orderedExerciseRecords.first { record in
                    if let exerciseID = exercise.exerciseID, let recordID = record.exerciseID {
                        return exerciseID == recordID
                    }
                    return exercise.exerciseNameSnapshot.caseInsensitiveCompare(
                        record.exerciseNameSnapshot
                    ) == .orderedSame
                }
            }
            .first
    }
}
