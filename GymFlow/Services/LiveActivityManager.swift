import ActivityKit
import Foundation
import OSLog
import SwiftData

struct WorkoutActivitySnapshot: Equatable {
    let exerciseName: String
    let currentSet: Int
    let totalSets: Int
    let completedExercises: Int
    let totalExercises: Int
    let workoutStartDate: Date
    let restEndDate: Date?
    let pausedRestSeconds: Int
    let restComplete: Bool
}

@MainActor
final class LiveActivityManager {
    static let shared = LiveActivityManager()

    private enum PersistenceKey {
        static let activityID = "workoutLiveActivity.identifier"
        static let sessionID = "workoutLiveActivity.sessionID"
        static let startedAt = "workoutLiveActivity.startedAt"
        static let lastUpdate = "workoutLiveActivity.lastSuccessfulUpdate"
    }

    private let defaults: UserDefaults
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "GymFlow",
        category: "LiveActivity"
    )
    private var endedSessionIDs: Set<UUID> = []
    private(set) var lastError: String?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    @discardableResult
    func reconcile(
        session: WorkoutActivitySessionState?,
        now: Date = Date()
    ) -> WorkoutActivityReconciliationPlan {
        let activities = Activity<WorkoutActivityAttributes>.activities
        let existing = activities.map {
            ExistingWorkoutActivity(
                activityID: $0.id,
                sessionID: $0.attributes.sessionID
            )
        }
        let plan = WorkoutActivityReconciler.plan(
            session: session,
            activities: existing,
            persistedActivityID: defaults.string(forKey: PersistenceKey.activityID),
            now: now
        )

        for activity in activities where plan.activityIDsToEnd.contains(activity.id) {
            endImmediately(activity)
        }

        guard let session, plan.validSessionID == session.sessionID else {
            clearPersistedActivityState()
            if let reason = plan.invalidReason {
                logger.info("Reconciled workout activities without a valid session: \(String(describing: reason), privacy: .public)")
            }
            return plan
        }

        endedSessionIDs.remove(session.sessionID)
        let state = contentState(from: session.snapshot)
        if let identifier = plan.activityIDToKeep,
           let activity = activities.first(where: { $0.id == identifier }) {
            Task {
                await activity.update(content(for: state))
                guard !endedSessionIDs.contains(session.sessionID) else { return }
                record(activity: activity, session: session, now: now)
                logger.debug("Updated workout Live Activity \(activity.id, privacy: .public)")
            }
        } else if plan.shouldStartActivity {
            requestActivity(for: session, state: state, now: now)
        }

        return plan
    }

    func reconcilePersistedWorkouts(
        _ sessions: [WorkoutSession],
        preferredSessionID: UUID?,
        modelContext: ModelContext,
        now: Date = Date()
    ) throws -> UUID? {
        let activeSessions = sessions.filter { $0.status == .active }
        let activityStates = Dictionary(uniqueKeysWithValues: activeSessions.map {
            ($0.id, sessionState(for: $0, now: now))
        })
        let validSessions = activeSessions.filter { session in
            guard let state = activityStates[session.id] else { return false }
            return WorkoutActivityReconciler.validationReason(for: state, now: now) == nil
        }
        let selectedSession = validSessions.first(where: { $0.id == preferredSessionID })
            ?? validSessions.first

        var changedStoredSessions = false
        for session in activeSessions where session.id != selectedSession?.id {
            session.status = .cancelled
            session.completedAt = now
            RestTimerService.clearPersistedState(
                defaults: defaults,
                keyPrefix: "restTimer.\(session.id.uuidString)"
            )
            changedStoredSessions = true
        }
        if changedStoredSessions {
            try modelContext.save()
        }

        guard let selectedSession, let state = activityStates[selectedSession.id] else {
            reconcile(session: nil, now: now)
            return nil
        }
        reconcile(session: state, now: now)
        return selectedSession.id
    }

    func startOrUpdate(
        sessionID: UUID,
        workoutName: String,
        snapshot: WorkoutActivitySnapshot
    ) {
        let session = WorkoutActivitySessionState(
            sessionID: sessionID,
            workoutName: workoutName,
            disposition: .active,
            startedAt: snapshot.workoutStartDate,
            hasValidWorkoutData: snapshot.totalExercises > 0,
            snapshot: snapshot
        )
        reconcile(session: session)
    }

    func end(sessionID: UUID, finalSnapshot: WorkoutActivitySnapshot) {
        endedSessionIDs.insert(sessionID)
        let state = contentState(from: finalSnapshot)
        let matchingActivities = Activity<WorkoutActivityAttributes>.activities.filter {
            $0.attributes.sessionID == sessionID
        }
        for activity in matchingActivities {
            Task {
                await activity.end(content(for: state), dismissalPolicy: .immediate)
                logger.info("Ended workout Live Activity \(activity.id, privacy: .public)")
            }
        }
        clearPersistedActivityState(ifSessionID: sessionID)
    }

    func endAll() {
        let activities = Activity<WorkoutActivityAttributes>.activities
        endedSessionIDs.formUnion(activities.map(\.attributes.sessionID))
        for activity in activities {
            endImmediately(activity)
        }
        clearPersistedActivityState()
    }

    private func requestActivity(
        for session: WorkoutActivitySessionState,
        state: WorkoutActivityAttributes.ContentState,
        now: Date
    ) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            logger.info("Live Activities are disabled for GymFlow")
            clearPersistedActivityState()
            return
        }
        do {
            let activity = try Activity.request(
                attributes: WorkoutActivityAttributes(
                    sessionID: session.sessionID,
                    workoutName: session.workoutName
                ),
                content: content(for: state),
                pushType: nil
            )
            if endedSessionIDs.contains(session.sessionID) {
                endImmediately(activity)
            } else {
                record(activity: activity, session: session, now: now)
                logger.info("Started workout Live Activity \(activity.id, privacy: .public)")
            }
            lastError = nil
        } catch {
            lastError = "Live Activity could not start. \(error.localizedDescription)"
            logger.error("Live Activity request failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func endImmediately(_ activity: Activity<WorkoutActivityAttributes>) {
        Task {
            await activity.end(nil, dismissalPolicy: .immediate)
            logger.info("Removed orphaned or duplicate Live Activity \(activity.id, privacy: .public)")
        }
    }

    private func record(
        activity: Activity<WorkoutActivityAttributes>,
        session: WorkoutActivitySessionState,
        now: Date
    ) {
        defaults.set(activity.id, forKey: PersistenceKey.activityID)
        defaults.set(session.sessionID.uuidString, forKey: PersistenceKey.sessionID)
        defaults.set(session.startedAt, forKey: PersistenceKey.startedAt)
        defaults.set(now, forKey: PersistenceKey.lastUpdate)
    }

    private func clearPersistedActivityState(ifSessionID sessionID: UUID? = nil) {
        if let sessionID,
           defaults.string(forKey: PersistenceKey.sessionID) != sessionID.uuidString {
            return
        }
        defaults.removeObject(forKey: PersistenceKey.activityID)
        defaults.removeObject(forKey: PersistenceKey.sessionID)
        defaults.removeObject(forKey: PersistenceKey.startedAt)
        defaults.removeObject(forKey: PersistenceKey.lastUpdate)
    }

    private func contentState(
        from snapshot: WorkoutActivitySnapshot
    ) -> WorkoutActivityAttributes.ContentState {
        WorkoutActivityAttributes.ContentState(
            exerciseName: snapshot.exerciseName,
            currentSet: snapshot.currentSet,
            totalSets: snapshot.totalSets,
            completedExercises: snapshot.completedExercises,
            totalExercises: snapshot.totalExercises,
            workoutStartDate: snapshot.workoutStartDate,
            restEndDate: snapshot.restEndDate,
            pausedRestSeconds: snapshot.pausedRestSeconds,
            restComplete: snapshot.restComplete,
            workoutExpiresAt: snapshot.workoutStartDate.addingTimeInterval(
                WorkoutActivityPolicy.maximumDuration
            )
        )
    }

    private func sessionState(
        for session: WorkoutSession,
        now: Date
    ) -> WorkoutActivitySessionState {
        let exercises = session.orderedExerciseRecords
        let savedIndex = session.currentExerciseIndex ?? exercises.firstIndex(where: {
            $0.orderedSets.contains(where: { !$0.isCompleted })
        }) ?? 0
        let exerciseIndex = min(max(0, savedIndex), max(0, exercises.count - 1))
        let exercise = exercises.indices.contains(exerciseIndex) ? exercises[exerciseIndex] : nil
        let currentSet = session.currentSetNumber
            ?? exercise?.orderedSets.first(where: { !$0.isCompleted })?.setNumber
            ?? exercise?.orderedSets.last?.setNumber
            ?? 1
        let completedExercises = exercises.filter { record in
            !record.orderedSets.isEmpty && record.orderedSets.allSatisfy(\.isCompleted)
        }.count
        let timerState = RestTimerService.persistedActivityState(
            defaults: defaults,
            keyPrefix: "restTimer.\(session.id.uuidString)",
            now: now
        )
        let snapshot = WorkoutActivitySnapshot(
            exerciseName: exercise?.exerciseNameSnapshot ?? "Workout status unavailable",
            currentSet: currentSet,
            totalSets: max(1, exercise?.orderedSets.count ?? 1),
            completedExercises: completedExercises,
            totalExercises: exercises.count,
            workoutStartDate: session.startedAt,
            restEndDate: timerState.deadline,
            pausedRestSeconds: timerState.pausedSeconds,
            restComplete: timerState.didComplete
        )
        return WorkoutActivitySessionState(
            sessionID: session.id,
            workoutName: session.planNameSnapshot,
            disposition: disposition(for: session.status),
            startedAt: session.startedAt,
            hasValidWorkoutData: !session.planNameSnapshot.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !exercises.isEmpty
                && exercises.allSatisfy { !$0.orderedSets.isEmpty },
            snapshot: snapshot
        )
    }

    private func disposition(
        for status: WorkoutSessionStatus
    ) -> WorkoutActivitySessionDisposition {
        switch status {
        case .planned: .planned
        case .active: .active
        case .completed: .completed
        case .cancelled: .cancelled
        }
    }

    private func content(
        for state: WorkoutActivityAttributes.ContentState
    ) -> ActivityContent<WorkoutActivityAttributes.ContentState> {
        ActivityContent(
            state: state,
            staleDate: WorkoutActivityPolicy.nextStaleDate(for: state)
        )
    }
}
