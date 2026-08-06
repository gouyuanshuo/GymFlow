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
            exercises: exercises
        )
    }

    static func makeSession(from plan: WorkoutPlan, now: Date = Date()) -> WorkoutSession {
        let records = plan.orderedExercises.map { exercise in
            let sets = (1...max(1, exercise.targetSets)).map { setNumber in
                WorkoutSetRecord(
                    setNumber: setNumber,
                    weight: max(0, exercise.targetWeight),
                    repetitions: max(0, exercise.targetRepetitions)
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
            status: .active,
            exerciseRecords: records
        )
    }
}
