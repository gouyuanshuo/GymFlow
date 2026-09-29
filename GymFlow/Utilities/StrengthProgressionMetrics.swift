import Foundation

/// The load and repetitions recorded for one completed set.
struct StrengthSetMetrics: Equatable {
    let weight: Double
    let repetitions: Int

    /// Epley's estimate is used only for sets of one through thirty repetitions.
    var estimatedOneRepMax: Double {
        guard weight > 0, repetitions > 0, repetitions <= 30 else { return weight }
        return weight * (1 + Double(repetitions) / 30)
    }
}

/// Shared rules for selecting and summarizing sets shown in strength history.
enum StrengthProgressionMetrics {
    static func strongestSet(in sets: [StrengthSetMetrics]) -> StrengthSetMetrics? {
        sets.max { $0.estimatedOneRepMax < $1.estimatedOneRepMax }
    }

    static func bestWeight(in sets: [StrengthSetMetrics]) -> Double {
        sets.map(\.weight).max() ?? 0
    }
}
