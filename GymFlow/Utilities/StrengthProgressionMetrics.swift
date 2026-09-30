import Foundation

/// The load and repetitions recorded for one completed set.
struct StrengthSetMetrics: Equatable {
    let weight: Double
    let repetitions: Int

    /// The canonical e1RM value, or `nil` when this set is outside the supported policy.
    var estimatedOneRepMax: Double? {
        ExercisePerformanceService.estimatedOneRepMax(
            weight: weight,
            repetitions: repetitions
        )
    }
}

/// Shared rules for selecting and summarizing sets shown in strength history.
enum StrengthProgressionMetrics {
    static func strongestSet(in sets: [StrengthSetMetrics]) -> StrengthSetMetrics? {
        sets.compactMap { set -> (set: StrengthSetMetrics, estimate: Double)? in
            guard let estimate = set.estimatedOneRepMax else { return nil }
            return (set, estimate)
        }
        .max { $0.estimate < $1.estimate }?
        .set
    }

    static func bestWeight(in sets: [StrengthSetMetrics]) -> Double {
        sets.map(\.weight).max() ?? 0
    }
}
