import Foundation
import SwiftData

@Model
final class ExerciseDefinition {
    @Attribute(.unique) var id: UUID
    var name: String
    var muscleGroup: String
    var secondaryMuscleGroups: [String] = []
    var equipment: String
    var defaultRestSeconds: Int?
    var defaultSets: Int?
    var defaultRepetitions: Int?
    var notes: String
    var isCustom: Bool
    var isArchived: Bool = false
    var createdAt: Date
    var updatedAt: Date = Date()

    init(
        id: UUID = UUID(),
        name: String,
        muscleGroup: String = "Other",
        secondaryMuscleGroups: [String] = [],
        equipment: String = "Other",
        defaultRestSeconds: Int? = nil,
        defaultSets: Int? = nil,
        defaultRepetitions: Int? = nil,
        notes: String = "",
        isCustom: Bool = false,
        isArchived: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.muscleGroup = muscleGroup
        self.secondaryMuscleGroups = secondaryMuscleGroups
        self.equipment = equipment
        self.defaultRestSeconds = defaultRestSeconds
        self.defaultSets = defaultSets
        self.defaultRepetitions = defaultRepetitions
        self.notes = notes
        self.isCustom = isCustom
        self.isArchived = isArchived
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
    }
}
