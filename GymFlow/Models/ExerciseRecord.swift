import Foundation
import SwiftData

@Model
final class ExerciseRecord {
    @Attribute(.unique) var id: UUID
    var exerciseID: UUID?
    var exerciseNameSnapshot: String
    var sortOrder: Int
    var restSeconds: Int
    @Relationship(deleteRule: .cascade) var sets: [WorkoutSetRecord]
    var notes: String

    init(
        id: UUID = UUID(),
        exerciseID: UUID? = nil,
        exerciseNameSnapshot: String,
        sortOrder: Int = 0,
        restSeconds: Int = 90,
        sets: [WorkoutSetRecord] = [],
        notes: String = ""
    ) {
        self.id = id
        self.exerciseID = exerciseID
        self.exerciseNameSnapshot = exerciseNameSnapshot
        self.sortOrder = sortOrder
        self.restSeconds = restSeconds
        self.sets = sets
        self.notes = notes
    }

    var orderedSets: [WorkoutSetRecord] { sets.sorted { $0.setNumber < $1.setNumber } }

    /// The first set still to be logged, or `nil` once every set is complete.
    var firstIncompleteSet: WorkoutSetRecord? {
        orderedSets.first { !$0.isCompleted }
    }

    /// Whether every set in this exercise has been logged.
    ///
    /// An exercise with no sets is not complete, so a plan entry that was never filled in does not
    /// silently count as finished work.
    var isFullyCompleted: Bool {
        !sets.isEmpty && sets.allSatisfy(\.isCompleted)
    }

    /// The set the user is working on inside this exercise.
    ///
    /// A session remembers the set number it was left on, so that one wins while it is still
    /// incomplete — otherwise the user resumes on the first unfinished set. The active workout
    /// screen, the Live Activity, and set completion all need this same answer, so it is defined
    /// once here rather than reimplemented with slightly different fallbacks in each.
    func currentSet(preferring savedSetNumber: Int?) -> WorkoutSetRecord? {
        if let savedSetNumber,
           let saved = orderedSets.first(where: { $0.setNumber == savedSetNumber && !$0.isCompleted }) {
            return saved
        }
        return firstIncompleteSet
    }
}
