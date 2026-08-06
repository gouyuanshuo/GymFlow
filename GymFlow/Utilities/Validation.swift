import Foundation

enum ValidationError: LocalizedError, Equatable {
    case emptyPlanName
    case emptyExerciseName
    case invalidSetCount
    case negativeRepetitions
    case negativeWeight
    case negativeRestTime

    var errorDescription: String? {
        switch self {
        case .emptyPlanName: "Enter a plan name."
        case .emptyExerciseName: "Enter an exercise name."
        case .invalidSetCount: "Sets must be at least one."
        case .negativeRepetitions: "Repetitions cannot be negative."
        case .negativeWeight: "Weight cannot be negative."
        case .negativeRestTime: "Rest time cannot be negative."
        }
    }
}

enum InputValidator {
    static func validatePlanName(_ value: String) throws {
        guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationError.emptyPlanName
        }
    }

    static func validateExerciseName(_ value: String) throws {
        guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationError.emptyExerciseName
        }
    }

    static func validate(sets: Int, repetitions: Int, weight: Double, restSeconds: Int) throws {
        guard sets >= 1 else { throw ValidationError.invalidSetCount }
        guard repetitions >= 0 else { throw ValidationError.negativeRepetitions }
        guard weight >= 0 else { throw ValidationError.negativeWeight }
        guard restSeconds >= 0 else { throw ValidationError.negativeRestTime }
    }
}
