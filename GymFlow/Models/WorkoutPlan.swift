import Foundation
import SwiftData

@Model
final class WorkoutPlan {
    @Attribute(.unique) var id: UUID
    var name: String
    var notes: String
    var createdAt: Date
    var updatedAt: Date
    var sortOrder: Int
    var assignedPlaylistID: UUID?
    @Relationship(deleteRule: .cascade) var exercises: [PlannedExercise]

    init(
        id: UUID = UUID(),
        name: String,
        notes: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        sortOrder: Int = 0,
        assignedPlaylistID: UUID? = nil,
        exercises: [PlannedExercise] = []
    ) {
        self.id = id
        self.name = name
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.sortOrder = sortOrder
        self.assignedPlaylistID = assignedPlaylistID
        self.exercises = exercises
    }

    var orderedExercises: [PlannedExercise] {
        exercises.sorted { lhs, rhs in
            lhs.sortOrder == rhs.sortOrder
                ? lhs.exerciseNameSnapshot < rhs.exerciseNameSnapshot
                : lhs.sortOrder < rhs.sortOrder
        }
    }

    /// A rough time budget for the plan, used before any history exists to estimate from.
    ///
    /// Counts a fixed allowance for performing each set plus the plan's own rest between them. Rest
    /// is counted between sets only, not after the last one, since the user moves straight on.
    var expectedDurationMinutes: Int {
        let seconds = orderedExercises.reduce(0) { result, exercise in
            let working = exercise.targetSets * Self.assumedSecondsPerSet
            let resting = max(0, exercise.targetSets - 1) * exercise.restSeconds
            return result + working + resting
        }
        return max(1, Int(ceil(Double(seconds) / 60)))
    }

    /// How long one set is assumed to take when there is no history to measure against.
    private static let assumedSecondsPerSet = 45
}
