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
    @Relationship(deleteRule: .cascade) var exercises: [PlannedExercise]

    init(
        id: UUID = UUID(),
        name: String,
        notes: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        sortOrder: Int = 0,
        exercises: [PlannedExercise] = []
    ) {
        self.id = id
        self.name = name
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.sortOrder = sortOrder
        self.exercises = exercises
    }

    var orderedExercises: [PlannedExercise] {
        exercises.sorted { lhs, rhs in
            lhs.sortOrder == rhs.sortOrder
                ? lhs.exerciseNameSnapshot < rhs.exerciseNameSnapshot
                : lhs.sortOrder < rhs.sortOrder
        }
    }

    var expectedDurationMinutes: Int {
        let seconds = orderedExercises.reduce(0) { result, exercise in
            result + (exercise.targetSets * 45) + (max(0, exercise.targetSets - 1) * exercise.restSeconds)
        }
        return max(1, Int(ceil(Double(seconds) / 60)))
    }
}

@Model
final class ExerciseDefinition {
    @Attribute(.unique) var id: UUID
    var name: String
    var muscleGroup: String
    var equipment: String
    var notes: String
    var isCustom: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        muscleGroup: String = "Other",
        equipment: String = "Other",
        notes: String = "",
        isCustom: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.muscleGroup = muscleGroup
        self.equipment = equipment
        self.notes = notes
        self.isCustom = isCustom
        self.createdAt = createdAt
    }
}

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

enum WorkoutSessionStatus: String, CaseIterable, Codable {
    case planned
    case active
    case completed
    case cancelled
}

@Model
final class WorkoutSession {
    @Attribute(.unique) var id: UUID
    var workoutPlanID: UUID?
    var planNameSnapshot: String
    var startedAt: Date
    var completedAt: Date?
    var notes: String
    private var statusRawValue: String
    @Relationship(deleteRule: .cascade) var exerciseRecords: [ExerciseRecord]

    init(
        id: UUID = UUID(),
        workoutPlanID: UUID? = nil,
        planNameSnapshot: String,
        startedAt: Date = Date(),
        completedAt: Date? = nil,
        notes: String = "",
        status: WorkoutSessionStatus = .planned,
        exerciseRecords: [ExerciseRecord] = []
    ) {
        self.id = id
        self.workoutPlanID = workoutPlanID
        self.planNameSnapshot = planNameSnapshot
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.notes = notes
        self.statusRawValue = status.rawValue
        self.exerciseRecords = exerciseRecords
    }

    var status: WorkoutSessionStatus {
        get { WorkoutSessionStatus(rawValue: statusRawValue) ?? .planned }
        set { statusRawValue = newValue.rawValue }
    }

    var orderedExerciseRecords: [ExerciseRecord] {
        exerciseRecords.sorted { $0.sortOrder < $1.sortOrder }
    }

    var duration: TimeInterval {
        max(0, (completedAt ?? Date()).timeIntervalSince(startedAt))
    }

    var completedSets: [WorkoutSetRecord] {
        orderedExerciseRecords.flatMap(\.orderedSets).filter(\.isCompleted)
    }

    var completedSetCount: Int { completedSets.count }
    var completedExerciseCount: Int {
        orderedExerciseRecords.filter { $0.orderedSets.contains(where: \.isCompleted) }.count
    }
    var totalRepetitions: Int { completedSets.reduce(0) { $0 + $1.repetitions } }
    var trainingVolume: Double { completedSets.reduce(0) { $0 + ($1.weight * Double($1.repetitions)) } }
}

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
}

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
