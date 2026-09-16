import ActivityKit
import Foundation

struct WorkoutActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var exerciseName: String
        var currentSetID: UUID?
        var currentSet: Int
        var totalSets: Int
        var targetWeight: Double
        var targetRepetitions: Int
        var lastCompletedExerciseName: String?
        var lastCompletedSetNumber: Int?
        var completedExercises: Int
        var totalExercises: Int
        var workoutStartDate: Date
        var restEndDate: Date?
        var pausedRestSeconds: Int
        var restComplete: Bool
        var workoutReadyToFinish: Bool
        var workoutExpiresAt: Date?
    }

    var sessionID: UUID
    var workoutName: String
}

enum WorkoutActivityDisplayState: Equatable {
    case resting(endDate: Date)
    case paused(seconds: Int)
    case ready
    case training(currentSet: Int, totalSets: Int)
    case stale
}

enum WorkoutActivityPolicy {
    static let maximumDuration: TimeInterval = 8 * 60 * 60

    static func nextStaleDate(
        for state: WorkoutActivityAttributes.ContentState
    ) -> Date? {
        let expiration = state.workoutExpiresAt
        guard let restEndDate = state.restEndDate else { return expiration }
        guard let expiration else { return restEndDate }
        return min(restEndDate, expiration)
    }

    static func displayState(
        for state: WorkoutActivityAttributes.ContentState,
        isStale: Bool,
        now: Date
    ) -> WorkoutActivityDisplayState {
        if let expiration = state.workoutExpiresAt, now >= expiration {
            return .stale
        }
        if state.restComplete {
            return .ready
        }
        if let restEndDate = state.restEndDate {
            return restEndDate > now ? .resting(endDate: restEndDate) : .ready
        }
        if state.pausedRestSeconds > 0 {
            return .paused(seconds: state.pausedRestSeconds)
        }
        if isStale, state.workoutExpiresAt == nil {
            return .stale
        }
        return .training(
            currentSet: max(1, state.currentSet),
            totalSets: max(1, state.totalSets)
        )
    }
}
