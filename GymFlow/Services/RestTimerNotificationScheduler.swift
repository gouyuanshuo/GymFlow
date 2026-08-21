import Foundation
import UserNotifications

struct RestTimerNotificationPlan: Equatable {
    let identifier: String
    let endDate: Date
    let soundEnabled: Bool
}

@MainActor
protocol RestTimerNotificationScheduling: AnyObject {
    func schedule(_ plan: RestTimerNotificationPlan)
    func cancel(identifier: String)
}

@MainActor
final class RestTimerNotificationScheduler: RestTimerNotificationScheduling {
    static let shared = RestTimerNotificationScheduler()
    nonisolated static let categoryIdentifier = "GYMFLOW_REST_TIMER"

    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    static func identifier(for sessionID: UUID) -> String {
        "com.gouyuanshuo.GymFlow.restTimer.\(sessionID.uuidString)"
    }

    func prepareAuthorization() {
        Task {
            let settings = await center.notificationSettings()
            guard settings.authorizationStatus == .notDetermined else { return }
            _ = try? await center.requestAuthorization(options: [.alert, .sound])
        }
    }

    func schedule(_ plan: RestTimerNotificationPlan) {
        Task { try? await scheduleAndWait(plan) }
    }

    func scheduleAndWait(
        _ plan: RestTimerNotificationPlan,
        now: Date = Date()
    ) async throws {
        center.removePendingNotificationRequests(withIdentifiers: [plan.identifier])
        center.removeDeliveredNotifications(withIdentifiers: [plan.identifier])

        let interval = plan.endDate.timeIntervalSince(now)
        guard interval > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = "Rest complete"
        content.body = "Ready for your next set."
        content.categoryIdentifier = Self.categoryIdentifier
        content.threadIdentifier = Self.categoryIdentifier
        content.interruptionLevel = .timeSensitive
        if plan.soundEnabled {
            content.sound = .default
        }

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(1, interval),
            repeats: false
        )
        let request = UNNotificationRequest(
            identifier: plan.identifier,
            content: content,
            trigger: trigger
        )
        try await center.add(request)
    }

    func cancel(identifier: String) {
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
    }
}
