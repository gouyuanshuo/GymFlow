import Foundation

@MainActor
struct PlanDraft {
    var name: String
    var notes: String
    var assignedPlaylistID: UUID?
    var exercises: [PlannedExerciseDraft]

    init(plan: WorkoutPlan? = nil) {
        name = plan?.name ?? ""
        notes = plan?.notes ?? ""
        assignedPlaylistID = plan?.assignedPlaylistID
        exercises = plan?.orderedExercises.map(PlannedExerciseDraft.init) ?? []
    }
}

@MainActor
struct PlannedExerciseDraft: Identifiable, Equatable {
    let id: UUID
    var exerciseID: UUID?
    var name: String
    var targetSets: Int
    var targetRepetitions: Int
    var targetWeight: Double
    var restSeconds: Int
    var notes: String

    init(definition: ExerciseDefinition, restSeconds: Int = 90) {
        id = UUID()
        exerciseID = definition.id
        name = definition.name
        targetSets = max(1, definition.defaultSets ?? 3)
        targetRepetitions = max(0, definition.defaultRepetitions ?? 10)
        targetWeight = 0
        self.restSeconds = max(0, definition.defaultRestSeconds ?? restSeconds)
        notes = ""
    }

    init(plannedExercise: PlannedExercise) {
        id = UUID()
        exerciseID = plannedExercise.exerciseID
        name = plannedExercise.exerciseNameSnapshot
        targetSets = plannedExercise.targetSets
        targetRepetitions = plannedExercise.targetRepetitions
        targetWeight = plannedExercise.targetWeight
        restSeconds = plannedExercise.restSeconds
        notes = plannedExercise.notes
    }
}
