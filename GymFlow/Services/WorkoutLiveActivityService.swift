import ActivityKit
import Foundation

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
final class WorkoutLiveActivityService {
    static let shared = WorkoutLiveActivityService()

    private var pendingSessionIDs: Set<UUID> = []
    private var endedSessionIDs: Set<UUID> = []
    private(set) var lastError: String?

    private init() { }

    func startOrUpdate(
        sessionID: UUID,
        workoutName: String,
        snapshot: WorkoutActivitySnapshot
    ) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        endedSessionIDs.remove(sessionID)
        let state = contentState(from: snapshot)

        if let activity = activity(for: sessionID) {
            Task {
                await activity.update(content(for: state))
            }
            return
        }

        guard !pendingSessionIDs.contains(sessionID) else { return }
        pendingSessionIDs.insert(sessionID)
        Task {
            defer { pendingSessionIDs.remove(sessionID) }
            do {
                let activity = try Activity.request(
                    attributes: WorkoutActivityAttributes(
                        sessionID: sessionID,
                        workoutName: workoutName
                    ),
                    content: content(for: state),
                    pushType: nil
                )
                if endedSessionIDs.contains(sessionID) {
                    await activity.end(content(for: state), dismissalPolicy: .immediate)
                }
                lastError = nil
            } catch {
                lastError = "Live Activity could not start. \(error.localizedDescription)"
            }
        }
    }

    func end(sessionID: UUID, finalSnapshot: WorkoutActivitySnapshot) {
        endedSessionIDs.insert(sessionID)
        guard let activity = activity(for: sessionID) else { return }
        let finalContent = content(for: contentState(from: finalSnapshot))
        Task {
            await activity.end(finalContent, dismissalPolicy: .immediate)
        }
    }

    func endAll() {
        let activities = Activity<WorkoutActivityAttributes>.activities
        endedSessionIDs.formUnion(activities.map(\.attributes.sessionID))
        for activity in activities {
            Task {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    private func activity(for sessionID: UUID) -> Activity<WorkoutActivityAttributes>? {
        Activity<WorkoutActivityAttributes>.activities.first {
            $0.attributes.sessionID == sessionID
        }
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
            restComplete: snapshot.restComplete
        )
    }

    private func content(
        for state: WorkoutActivityAttributes.ContentState
    ) -> ActivityContent<WorkoutActivityAttributes.ContentState> {
        ActivityContent(
            state: state,
            staleDate: state.restEndDate?.addingTimeInterval(300)
        )
    }
}
