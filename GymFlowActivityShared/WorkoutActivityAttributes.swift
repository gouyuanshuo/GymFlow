import ActivityKit
import Foundation

struct WorkoutActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var exerciseName: String
        var currentSet: Int
        var totalSets: Int
        var completedExercises: Int
        var totalExercises: Int
        var workoutStartDate: Date
        var restEndDate: Date?
        var pausedRestSeconds: Int
        var restComplete: Bool
    }

    var sessionID: UUID
    var workoutName: String
}
