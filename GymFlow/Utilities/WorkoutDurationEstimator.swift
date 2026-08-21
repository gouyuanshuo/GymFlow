import Foundation

enum WorkoutDurationEstimateSource: Equatable {
    case staticPlan
    case history
}

struct WorkoutDurationEstimate: Equatable {
    let duration: TimeInterval
    let source: WorkoutDurationEstimateSource
    let sampleCount: Int

    var roundedMinutes: Int {
        max(1, Int((duration / 60).rounded()))
    }
}

enum WorkoutDurationEstimator {
    static let recentSessionLimit = 5
    static let maximumValidDuration: TimeInterval = 8 * 60 * 60

    static func estimate(
        for plan: WorkoutPlan,
        sessions: [WorkoutSession]
    ) -> WorkoutDurationEstimate {
        let recentDurations = sessions.compactMap { session -> (Date, TimeInterval)? in
            guard session.workoutPlanID == plan.id,
                  session.status == .completed,
                  let completedAt = session.completedAt else {
                return nil
            }
            let duration = completedAt.timeIntervalSince(session.startedAt)
            guard duration.isFinite,
                  duration > 0,
                  duration < maximumValidDuration else {
                return nil
            }
            return (completedAt, duration)
        }
        .sorted { lhs, rhs in lhs.0 > rhs.0 }
        .prefix(recentSessionLimit)
        .map { $0.1 }

        guard !recentDurations.isEmpty else {
            return WorkoutDurationEstimate(
                duration: TimeInterval(plan.expectedDurationMinutes * 60),
                source: .staticPlan,
                sampleCount: 0
            )
        }

        let historicalDuration: TimeInterval
        if recentDurations.count <= 2 {
            historicalDuration = recentDurations.reduce(0, +) / Double(recentDurations.count)
        } else {
            historicalDuration = median(recentDurations)
        }
        return WorkoutDurationEstimate(
            duration: historicalDuration,
            source: .history,
            sampleCount: recentDurations.count
        )
    }

    private static func median(_ values: [TimeInterval]) -> TimeInterval {
        let sorted = values.sorted()
        let middle = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return (sorted[middle - 1] + sorted[middle]) / 2
        }
        return sorted[middle]
    }
}
