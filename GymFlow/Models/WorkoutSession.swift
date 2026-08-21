import Foundation
import SwiftData

@Model
final class WorkoutSession {
    @Attribute(.unique) var id: UUID
    var workoutPlanID: UUID?
    var planNameSnapshot: String
    var startedAt: Date
    var completedAt: Date?
    var notes: String
    var currentExerciseIndex: Int?
    var currentSetNumber: Int?
    var playlistID: UUID?
    var playlistNameSnapshot: String?
    /// Backing storage for ``status``. Not `private` because `#Predicate` can only reference
    /// stored properties, and queries need to filter sessions by status in the store rather than
    /// fetching everything and filtering in memory. Prefer ``status`` everywhere else.
    var statusRawValue: String
    @Relationship(deleteRule: .cascade) var exerciseRecords: [ExerciseRecord]

    init(
        id: UUID = UUID(),
        workoutPlanID: UUID? = nil,
        planNameSnapshot: String,
        startedAt: Date = Date(),
        completedAt: Date? = nil,
        notes: String = "",
        currentExerciseIndex: Int? = nil,
        currentSetNumber: Int? = nil,
        playlistID: UUID? = nil,
        playlistNameSnapshot: String? = nil,
        status: WorkoutSessionStatus = .planned,
        exerciseRecords: [ExerciseRecord] = []
    ) {
        self.id = id
        self.workoutPlanID = workoutPlanID
        self.planNameSnapshot = planNameSnapshot
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.notes = notes
        self.currentExerciseIndex = currentExerciseIndex
        self.currentSetNumber = currentSetNumber
        self.playlistID = playlistID
        self.playlistNameSnapshot = playlistNameSnapshot
        self.statusRawValue = status.rawValue
        self.exerciseRecords = exerciseRecords
    }

    var status: WorkoutSessionStatus {
        get { WorkoutSessionStatus(rawValue: statusRawValue) ?? .planned }
        set { statusRawValue = newValue.rawValue }
    }

    /// Matches sessions in a given status, for `@Query` and `FetchDescriptor`.
    ///
    /// Written here so call sites filter by the `WorkoutSessionStatus` case rather than repeating
    /// its raw string, which `#Predicate` would otherwise force them to do.
    static func predicate(status: WorkoutSessionStatus) -> Predicate<WorkoutSession> {
        let rawValue = status.rawValue
        return #Predicate<WorkoutSession> { $0.statusRawValue == rawValue }
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

    /// Everything the summary screens report about this workout, gathered in one pass.
    ///
    /// The completion screen, the history rows, and the share card each show several of these
    /// figures side by side. Reading them through the individual properties below would re-sort the
    /// exercise records and re-scan every set once per figure, so screens showing more than one
    /// should read ``totals`` instead.
    var totals: WorkoutTotals {
        var totals = WorkoutTotals()
        for exercise in exerciseRecords {
            var exerciseHasCompletedSet = false
            for set in exercise.sets where set.isCompleted {
                exerciseHasCompletedSet = true
                totals.setCount += 1
                totals.repetitions += set.repetitions
                totals.volume += set.weight * Double(set.repetitions)
            }
            if exerciseHasCompletedSet { totals.exerciseCount += 1 }
        }
        return totals
    }

    var completedSetCount: Int { totals.setCount }
    var completedExerciseCount: Int { totals.exerciseCount }
    var totalRepetitions: Int { totals.repetitions }
    var trainingVolume: Double { totals.volume }
}

/// The headline figures for one workout: how much was actually logged.
struct WorkoutTotals: Equatable {
    /// Exercises with at least one completed set.
    var exerciseCount = 0
    var setCount = 0
    var repetitions = 0
    /// Weight times repetitions across every completed set, in kilograms.
    var volume: Double = 0
}
