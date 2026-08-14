import Foundation

struct WorkoutShareSummary: Equatable {
    let workoutName: String
    let date: Date
    let duration: TimeInterval
    let exerciseCount: Int
    let setCount: Int
    let repetitionCount: Int
    let trainingVolume: Double
    let exerciseHighlights: [WorkoutShareExerciseHighlight]

    var displayWorkoutName: String {
        WorkoutShareSummaryBuilder.displayName(for: workoutName)
    }

    var accessibilityDescription: String {
        let exerciseWord = exerciseCount == 1 ? "exercise" : "exercises"
        let setWord = setCount == 1 ? "set" : "sets"
        return "\(workoutName), \(WorkoutShareFormatters.duration(duration)), "
            + "\(exerciseCount) \(exerciseWord), \(setCount) \(setWord), "
            + "\(WorkoutShareFormatters.exactVolume(trainingVolume))."
    }
}

struct WorkoutShareExerciseHighlight: Equatable, Identifiable {
    let name: String
    let weight: Double
    let repetitions: Int
    let exerciseVolume: Double
    let sortOrder: Int

    var id: String { "\(sortOrder)-\(name)" }
    var topSetDescription: String {
        WorkoutShareFormatters.set(weight: weight, repetitions: repetitions)
    }
}

enum WorkoutShareError: LocalizedError, Equatable {
    case workoutNotCompleted
    case missingCompletionDate
    case noCompletedSets
    case imageRenderFailed

    var errorDescription: String? {
        switch self {
        case .workoutNotCompleted:
            "Finish this workout before creating a share card."
        case .missingCompletionDate:
            "This workout is missing its completion time and can’t be shared yet."
        case .noCompletedSets:
            "Complete at least one set before creating a share card."
        case .imageRenderFailed:
            "GymFlow couldn’t create the workout image. Try another background and share again."
        }
    }
}

enum WorkoutShareSummaryBuilder {
    static let maximumDisplayNameLength = 64
    static let maximumHighlights = 3

    static func build(from session: WorkoutSession) throws -> WorkoutShareSummary {
        guard session.status == .completed else {
            throw WorkoutShareError.workoutNotCompleted
        }
        guard let completedAt = session.completedAt else {
            throw WorkoutShareError.missingCompletionDate
        }
        guard !session.completedSets.isEmpty else {
            throw WorkoutShareError.noCompletedSets
        }

        return WorkoutShareSummary(
            workoutName: normalizedWorkoutName(session.planNameSnapshot),
            date: session.startedAt,
            duration: max(0, completedAt.timeIntervalSince(session.startedAt)),
            exerciseCount: session.completedExerciseCount,
            setCount: session.completedSetCount,
            repetitionCount: session.totalRepetitions,
            trainingVolume: session.trainingVolume,
            exerciseHighlights: highlights(from: session.orderedExerciseRecords)
        )
    }

    static func displayName(for value: String) -> String {
        let normalized = normalizedWorkoutName(value)
        guard normalized.count > maximumDisplayNameLength else { return normalized }
        let endIndex = normalized.index(
            normalized.startIndex,
            offsetBy: maximumDisplayNameLength - 1
        )
        return String(normalized[..<endIndex]).trimmingCharacters(in: .whitespaces) + "…"
    }

    private static func normalizedWorkoutName(_ value: String) -> String {
        let normalized = value
            .split(whereSeparator: \Character.isWhitespace)
            .joined(separator: " ")
        return normalized.isEmpty ? "Workout" : normalized
    }

    private static func highlights(
        from records: [ExerciseRecord]
    ) -> [WorkoutShareExerciseHighlight] {
        records.compactMap { record -> WorkoutShareExerciseHighlight? in
            let completedSets = record.orderedSets.filter(\.isCompleted)
            guard let topSet = completedSets.max(by: { lhs, rhs in
                let lhsVolume = lhs.weight * Double(lhs.repetitions)
                let rhsVolume = rhs.weight * Double(rhs.repetitions)
                if lhsVolume != rhsVolume { return lhsVolume < rhsVolume }
                if lhs.weight != rhs.weight { return lhs.weight < rhs.weight }
                if lhs.repetitions != rhs.repetitions {
                    return lhs.repetitions < rhs.repetitions
                }
                return lhs.setNumber > rhs.setNumber
            }) else { return nil }
            let volume = completedSets.reduce(0) {
                $0 + ($1.weight * Double($1.repetitions))
            }
            return WorkoutShareExerciseHighlight(
                name: record.exerciseNameSnapshot,
                weight: topSet.weight,
                repetitions: topSet.repetitions,
                exerciseVolume: volume,
                sortOrder: record.sortOrder
            )
        }
        .sorted { lhs, rhs in
            if lhs.exerciseVolume != rhs.exerciseVolume {
                return lhs.exerciseVolume > rhs.exerciseVolume
            }
            return lhs.sortOrder < rhs.sortOrder
        }
        .prefix(maximumHighlights)
        .map { $0 }
    }
}

enum WorkoutShareFormatters {
    static func duration(_ interval: TimeInterval) -> String {
        let totalSeconds = max(0, Int(interval))
        guard totalSeconds >= 60 else { return "<1m" }
        let totalMinutes = totalSeconds / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0, minutes > 0 { return "\(hours)h \(minutes)m" }
        if hours > 0 { return "\(hours)h" }
        return "\(minutes)m"
    }

    static func compactVolume(_ value: Double) -> String {
        let safeValue = max(0, value)
        if safeValue >= 1_000_000 {
            return "\(compactNumber(safeValue / 1_000_000))M kg"
        }
        if safeValue >= 1_000 {
            return "\(compactNumber(safeValue / 1_000))K kg"
        }
        return "\(GymFlowFormatters.weight(safeValue)) kg"
    }

    static func exactVolume(_ value: Double) -> String {
        "\(GymFlowFormatters.weight(max(0, value))) kilograms volume"
    }

    static func set(weight: Double, repetitions: Int) -> String {
        if weight > 0 {
            return "\(GymFlowFormatters.weight(weight)) kg × \(max(0, repetitions))"
        }
        return "\(max(0, repetitions)) reps"
    }

    private static func compactNumber(_ value: Double) -> String {
        if value >= 100 || value.rounded() == value {
            return String(format: "%.0f", value)
        }
        return String(format: "%.1f", value)
    }
}
