import Foundation

/// The `UserDefaults` layout the rest timer persists itself into.
///
/// The timer has to survive the app being suspended or killed mid-rest, so its whole state is
/// mirrored into defaults under a per-session prefix. Six call sites across the app, the widget
/// coordinator, and the Live Activity read or clear that state, so the key spelling lives here
/// instead of being rebuilt by string interpolation at each one.
enum RestTimerStorage {
    /// The prefix used before rest timers were scoped to a session. Existing state is migrated off
    /// it on first launch after the upgrade; see `RestTimerService.migrateStateIfNeeded(from:)`.
    static let legacyKeyPrefix = "restTimer"

    /// The prefix for one workout's rest timer.
    static func keyPrefix(for sessionID: UUID) -> String {
        "\(legacyKeyPrefix).\(sessionID.uuidString)"
    }

    /// One stored field of a rest timer's state.
    enum Field: String, CaseIterable {
        case endDate
        case pausedRemaining
        case originalDuration
        case isPaused
        case didComplete

        /// The fields describing a timer that is currently counting down.
        ///
        /// `didComplete` is deliberately excluded: it outlives the countdown so the completion
        /// banner still appears after the timer itself has been torn down.
        static let countdown: [Field] = [.endDate, .pausedRemaining, .originalDuration, .isPaused]
    }

    static func key(_ field: Field, prefix: String) -> String {
        "\(prefix).\(field.rawValue)"
    }
}
