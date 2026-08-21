import Foundation

enum WorkoutActivitySessionDisposition: Equatable {
    case planned
    case active
    case completed
    case cancelled
}

enum WorkoutActivityInvalidReason: Equatable {
    case noActiveWorkout
    case inactiveWorkout
    case missingWorkoutData
    case expiredWorkout
    case futureStartDate
}

struct WorkoutActivitySessionState: Equatable {
    let sessionID: UUID
    let workoutName: String
    let disposition: WorkoutActivitySessionDisposition
    let startedAt: Date
    let hasValidWorkoutData: Bool
    let snapshot: WorkoutActivitySnapshot
}

struct ExistingWorkoutActivity: Equatable {
    let activityID: String
    let sessionID: UUID
}

struct WorkoutActivityReconciliationPlan: Equatable {
    let validSessionID: UUID?
    let activityIDToKeep: String?
    let activityIDsToEnd: [String]
    let shouldStartActivity: Bool
    let shouldUpdateActivity: Bool
    let invalidReason: WorkoutActivityInvalidReason?
}

enum WorkoutActivityReconciler {
    static let allowedClockSkew: TimeInterval = 5 * 60

    static func plan(
        session: WorkoutActivitySessionState?,
        activities: [ExistingWorkoutActivity],
        persistedActivityID: String?,
        now: Date
    ) -> WorkoutActivityReconciliationPlan {
        if let reason = validationReason(for: session, now: now) {
            return invalidPlan(reason: reason, activities: activities)
        }
        guard let session else { return invalidPlan(reason: .noActiveWorkout, activities: activities) }

        let matchingActivities = activities.filter { $0.sessionID == session.sessionID }
        let activityToKeep = matchingActivities.first(where: {
            $0.activityID == persistedActivityID
        }) ?? matchingActivities.first
        let identifiersToEnd = activities
            .filter { $0.activityID != activityToKeep?.activityID }
            .map(\.activityID)
            .sorted()

        return WorkoutActivityReconciliationPlan(
            validSessionID: session.sessionID,
            activityIDToKeep: activityToKeep?.activityID,
            activityIDsToEnd: identifiersToEnd,
            shouldStartActivity: activityToKeep == nil,
            shouldUpdateActivity: activityToKeep != nil,
            invalidReason: nil
        )
    }

    static func validationReason(
        for session: WorkoutActivitySessionState?,
        now: Date
    ) -> WorkoutActivityInvalidReason? {
        guard let session else { return .noActiveWorkout }
        guard session.disposition == .active else { return .inactiveWorkout }
        guard session.hasValidWorkoutData else { return .missingWorkoutData }
        guard session.startedAt <= now.addingTimeInterval(allowedClockSkew) else {
            return .futureStartDate
        }
        guard now < session.startedAt.addingTimeInterval(WorkoutActivityPolicy.maximumDuration) else {
            return .expiredWorkout
        }
        return nil
    }

    private static func invalidPlan(
        reason: WorkoutActivityInvalidReason,
        activities: [ExistingWorkoutActivity]
    ) -> WorkoutActivityReconciliationPlan {
        WorkoutActivityReconciliationPlan(
            validSessionID: nil,
            activityIDToKeep: nil,
            activityIDsToEnd: activities.map(\.activityID).sorted(),
            shouldStartActivity: false,
            shouldUpdateActivity: false,
            invalidReason: reason
        )
    }
}
