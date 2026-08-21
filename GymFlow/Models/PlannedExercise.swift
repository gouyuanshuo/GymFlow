import Foundation
import SwiftData

@Model
final class PlannedExercise {
    @Attribute(.unique) var id: UUID
    var exerciseID: UUID?
    var exerciseNameSnapshot: String
    var targetSets: Int
    var targetRepetitions: Int
    var targetWeight: Double
    var restSeconds: Int
    var notes: String
    var sortOrder: Int

    init(
        id: UUID = UUID(),
        exerciseID: UUID? = nil,
        exerciseNameSnapshot: String,
        targetSets: Int = 3,
        targetRepetitions: Int = 10,
        targetWeight: Double = 0,
        restSeconds: Int = 90,
        notes: String = "",
        sortOrder: Int = 0
    ) {
        self.id = id
        self.exerciseID = exerciseID
        self.exerciseNameSnapshot = exerciseNameSnapshot
        self.targetSets = targetSets
        self.targetRepetitions = targetRepetitions
        self.targetWeight = targetWeight
        self.restSeconds = restSeconds
        self.notes = notes
        self.sortOrder = sortOrder
    }
}
