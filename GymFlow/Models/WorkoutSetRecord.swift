import Foundation
import SwiftData

@Model
final class WorkoutSetRecord {
    @Attribute(.unique) var id: UUID
    var setNumber: Int
    var weight: Double
    var repetitions: Int
    var isCompleted: Bool
    var completedAt: Date?
    var isWarmup: Bool

    init(
        id: UUID = UUID(),
        setNumber: Int,
        weight: Double = 0,
        repetitions: Int = 0,
        isCompleted: Bool = false,
        completedAt: Date? = nil,
        isWarmup: Bool = false
    ) {
        self.id = id
        self.setNumber = setNumber
        self.weight = weight
        self.repetitions = repetitions
        self.isCompleted = isCompleted
        self.completedAt = completedAt
        self.isWarmup = isWarmup
    }
}
