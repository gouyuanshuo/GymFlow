import Foundation

@MainActor
enum WorkoutFinalizationService {
    static func persist(
        session: WorkoutSession,
        status: WorkoutSessionStatus,
        completedAt: Date,
        restTimer: RestTimerService,
        save: () throws -> Void
    ) throws {
        let previousStatus = session.status
        let previousCompletion = session.completedAt
        session.status = status
        session.completedAt = completedAt
        do {
            try save()
        } catch {
            session.status = previousStatus
            session.completedAt = previousCompletion
            throw error
        }
        restTimer.cancel()
    }
}
