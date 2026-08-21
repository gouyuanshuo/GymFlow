import Foundation
import SwiftData
import UIKit

@available(iOS 17.0, *)
@MainActor
final class WorkoutActivityIntentCoordinator {
    static let shared = WorkoutActivityIntentCoordinator()

    private var container: ModelContainer?
    private let defaults = UserDefaults.standard
    private let notifications = RestTimerNotificationScheduler.shared

    private init() {
        WorkoutActivityIntentBridge.install(
            complete: { sessionID, setID, now in
                await WorkoutActivityIntentCoordinator.shared.completeCurrentSet(
                    sessionID: sessionID,
                    setID: setID,
                    now: now
                )
            },
            addThirtySeconds: { sessionID, now in
                await WorkoutActivityIntentCoordinator.shared.addThirtySeconds(
                    sessionID: sessionID,
                    now: now
                )
            },
            skipRest: { sessionID, now in
                await WorkoutActivityIntentCoordinator.shared.skipRest(
                    sessionID: sessionID,
                    now: now
                )
            }
        )
    }

    func configure(container: ModelContainer) {
        self.container = container
    }

    func completeCurrentSet(
        sessionID: UUID,
        setID: UUID,
        now: Date = Date()
    ) async {
        guard let session = fetchActiveSession(id: sessionID) else {
            LiveActivityManager.shared.end(sessionID: sessionID, finalSnapshot: .unavailable(now: now))
            return
        }

        let result = WorkoutActionService.completeCurrentSet(
            in: session,
            expectedSetID: setID,
            now: now
        )

        if result.didCompleteSet {
            do {
                try container?.mainContext.save()
            } catch {
                container?.mainContext.rollback()
                if let restoredSession = fetchActiveSession(id: sessionID) {
                    await LiveActivityManager.shared.updateImmediately(
                        session: restoredSession,
                        now: now
                    )
                }
                return
            }

            let timer = makeTimer(for: sessionID)
            timer.setNotificationSoundEnabled(timerSoundEnabled)
            timer.start(duration: result.restDuration, now: now)
            if let deadline = timer.deadline {
                try? await notifications.scheduleAndWait(RestTimerNotificationPlan(
                    identifier: RestTimerNotificationScheduler.identifier(for: sessionID),
                    endDate: deadline,
                    soundEnabled: timerSoundEnabled
                ), now: now)
            } else {
                notifications.cancel(
                    identifier: RestTimerNotificationScheduler.identifier(for: sessionID)
                )
            }

            if hapticFeedbackEnabled {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        } else {
            try? container?.mainContext.save()
        }

        await LiveActivityManager.shared.updateImmediately(session: session, now: now)
    }

    func addThirtySeconds(sessionID: UUID, now: Date = Date()) async {
        guard let session = fetchActiveSession(id: sessionID) else { return }
        let timerKey = RestTimerStorage.keyPrefix(for: sessionID)
        let persistedState = RestTimerService.persistedActivityState(
            defaults: defaults,
            keyPrefix: timerKey,
            now: now
        )
        guard persistedState.deadline != nil || persistedState.pausedSeconds > 0 else {
            await LiveActivityManager.shared.updateImmediately(session: session, now: now)
            return
        }
        let timer = makeTimer(for: sessionID)
        timer.setNotificationSoundEnabled(timerSoundEnabled)
        timer.addThirtySeconds(now: now)
        if let deadline = timer.deadline {
            try? await notifications.scheduleAndWait(RestTimerNotificationPlan(
                identifier: RestTimerNotificationScheduler.identifier(for: sessionID),
                endDate: deadline,
                soundEnabled: timerSoundEnabled
            ), now: now)
        }
        await LiveActivityManager.shared.updateImmediately(session: session, now: now)
    }

    func skipRest(sessionID: UUID, now: Date = Date()) async {
        guard let session = fetchActiveSession(id: sessionID) else { return }
        let timer = makeTimer(for: sessionID)
        timer.skip()
        notifications.cancel(identifier: RestTimerNotificationScheduler.identifier(for: sessionID))
        await LiveActivityManager.shared.updateImmediately(session: session, now: now)
    }

    private func fetchActiveSession(id: UUID) -> WorkoutSession? {
        guard let container else { return nil }
        var descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try? container.mainContext.fetch(descriptor).first(where: { $0.status == .active })
    }

    private func makeTimer(for sessionID: UUID) -> RestTimerService {
        RestTimerService(
            defaults: defaults,
            keyPrefix: RestTimerStorage.keyPrefix(for: sessionID),
            sessionID: sessionID
        )
    }

    private var timerSoundEnabled: Bool {
        defaults.object(forKey: "timerSoundEnabled") as? Bool ?? true
    }

    private var hapticFeedbackEnabled: Bool {
        defaults.object(forKey: "hapticFeedbackEnabled") as? Bool ?? true
    }
}
