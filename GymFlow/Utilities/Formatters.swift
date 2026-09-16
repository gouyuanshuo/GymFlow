import Foundation

enum GymFlowFormatters {
    static func duration(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval))
        let hours = total / 3_600
        let minutes = (total % 3_600) / 60
        let seconds = total % 60
        if hours > 0 { return String(format: "%d:%02d:%02d", hours, minutes, seconds) }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    static func weight(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...1)))
    }

    /// The canonical one-line description of a logged set.
    ///
    /// Bodyweight sets (no weight) read as "12 reps" rather than "0 kg × 12". Every screen that
    /// renders a set goes through here so the same set never displays differently in two places.
    static func set(weight: Double, repetitions: Int) -> String {
        let reps = max(0, repetitions)
        guard weight > 0 else { return "\(reps) reps" }
        return "\(self.weight(weight)) kg × \(reps)"
    }

    /// The VoiceOver reading of a logged set, matching `set(weight:repetitions:)`.
    static func setAccessibilityLabel(weight: Double, repetitions: Int) -> String {
        let reps = max(0, repetitions)
        guard weight > 0 else { return "\(reps) repetitions" }
        return "\(self.weight(weight)) kilograms, \(reps) repetitions"
    }
}
