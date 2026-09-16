import Foundation

/// The `UserDefaults` keys GymFlow stores its preferences and resume state under.
///
/// `@AppStorage` takes a raw string, so without this the same key is retyped in every screen that
/// reads it — and a single typo silently splits one setting into two that never see each other's
/// value. Collecting them here also makes it possible to see the app's whole persisted surface at
/// a glance before changing or migrating any of it.
enum PreferenceKey {
    /// Rest duration applied to newly added plan exercises, in seconds.
    static let defaultRestDuration = "defaultRestDuration"
    /// Whether the rest timer plays a sound when it finishes.
    static let timerSoundEnabled = "timerSoundEnabled"
    /// Whether the rest timer vibrates when it finishes.
    static let hapticFeedbackEnabled = "hapticFeedbackEnabled"
    /// Whether starting a workout also starts its assigned playlist.
    static let automaticallyPlayAssignedPlaylist = "automaticallyPlayAssignedPlaylist"
    /// Sort order chosen in the music library.
    static let musicLibrarySort = "musicLibrarySort"

    /// The plan shown on the Today screen, as a UUID string.
    static let selectedWorkoutPlanID = "selectedWorkoutPlanID"
    /// The workout to resume on launch, as a UUID string. Empty when no workout is in progress.
    static let activeWorkoutSessionID = "activeWorkoutSessionID"
}

