import Foundation

enum ExerciseLibraryError: LocalizedError, Equatable {
    case duplicateName(String)

    var errorDescription: String? {
        switch self {
        case .duplicateName(let name):
            "An exercise named \u{201c}\(name)\u{201d} already exists. Open that exercise instead of creating a duplicate."
        }
    }
}

struct ExerciseDefinitionInput: Equatable {
    var name: String
    var muscleGroup: String
    var secondaryMuscleGroups: [String]
    var equipment: String
    var defaultRestSeconds: Int?
    var defaultSets: Int?
    var defaultRepetitions: Int?
    var notes: String
}

enum ExerciseTaxonomy {
    static let muscleGroups = [
        "Chest", "Back", "Shoulders", "Biceps", "Triceps", "Quads",
        "Hamstrings", "Glutes", "Calves", "Core", "Cardio", "Full Body", "Other"
    ]

    static let equipment = [
        "Barbell", "Dumbbell", "Cable", "Machine", "Bodyweight", "Smith Machine",
        "Resistance Band", "Kettlebell", "Cardio Machine", "Other"
    ]
}

enum ExerciseLibraryService {
    static func normalizedName(_ value: String) -> String {
        value
            .split(whereSeparator: \Character.isWhitespace)
            .joined(separator: " ")
            .folding(
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: Locale(identifier: "en_US_POSIX")
            )
    }

    static func validateName(
        _ value: String,
        excludingID: UUID? = nil,
        existingDefinitions: [ExerciseDefinition]
    ) throws -> String {
        try InputValidator.validateExerciseName(value)
        let trimmedName = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = normalizedName(trimmedName)
        if existingDefinitions.contains(where: {
            $0.id != excludingID && normalizedName($0.name) == normalized
        }) {
            throw ExerciseLibraryError.duplicateName(trimmedName)
        }
        return trimmedName
    }

    static func create(
        input: ExerciseDefinitionInput,
        existingDefinitions: [ExerciseDefinition],
        now: Date = Date()
    ) throws -> ExerciseDefinition {
        let name = try validateName(input.name, existingDefinitions: existingDefinitions)
        try validateDefaults(input)
        return ExerciseDefinition(
            name: name,
            muscleGroup: normalizedMetadata(input.muscleGroup),
            secondaryMuscleGroups: normalizedSecondaryMuscles(input.secondaryMuscleGroups),
            equipment: normalizedMetadata(input.equipment),
            defaultRestSeconds: input.defaultRestSeconds,
            defaultSets: input.defaultSets,
            defaultRepetitions: input.defaultRepetitions,
            notes: input.notes.trimmingCharacters(in: .whitespacesAndNewlines),
            isCustom: true,
            createdAt: now,
            updatedAt: now
        )
    }

    static func update(
        _ definition: ExerciseDefinition,
        input: ExerciseDefinitionInput,
        existingDefinitions: [ExerciseDefinition],
        plans: [WorkoutPlan],
        now: Date = Date()
    ) throws {
        let name = try validateName(
            input.name,
            excludingID: definition.id,
            existingDefinitions: existingDefinitions
        )
        try validateDefaults(input)
        definition.name = name
        definition.muscleGroup = normalizedMetadata(input.muscleGroup)
        definition.secondaryMuscleGroups = normalizedSecondaryMuscles(input.secondaryMuscleGroups)
        definition.equipment = normalizedMetadata(input.equipment)
        definition.defaultRestSeconds = input.defaultRestSeconds
        definition.defaultSets = input.defaultSets
        definition.defaultRepetitions = input.defaultRepetitions
        definition.notes = input.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        definition.updatedAt = now
        synchronizePlannedExerciseSnapshots(for: definition, plans: plans)
    }

    static func setArchived(
        _ isArchived: Bool,
        for definition: ExerciseDefinition,
        now: Date = Date()
    ) {
        definition.isArchived = isArchived
        definition.updatedAt = now
    }

    static func isUsed(
        _ definition: ExerciseDefinition,
        plans: [WorkoutPlan],
        sessions: [WorkoutSession]
    ) -> Bool {
        let normalizedDefinitionName = normalizedName(definition.name)
        let isUsedByPlan = plans.contains { plan in
            plan.exercises.contains { exercise in
                exercise.exerciseID == definition.id
                    || (exercise.exerciseID == nil
                        && normalizedName(exercise.exerciseNameSnapshot) == normalizedDefinitionName)
            }
        }
        guard !isUsedByPlan else { return true }
        return sessions.contains { session in
            session.exerciseRecords.contains { record in
                record.exerciseID == definition.id
                    || (record.exerciseID == nil
                        && normalizedName(record.exerciseNameSnapshot) == normalizedDefinitionName)
            }
        }
    }

    static func synchronizePlannedExerciseSnapshots(
        for definition: ExerciseDefinition,
        plans: [WorkoutPlan]
    ) {
        for plan in plans {
            var changed = false
            for exercise in plan.exercises where exercise.exerciseID == definition.id {
                if exercise.exerciseNameSnapshot != definition.name {
                    exercise.exerciseNameSnapshot = definition.name
                    changed = true
                }
            }
            if changed {
                plan.updatedAt = definition.updatedAt
            }
        }
    }

    private static func validateDefaults(_ input: ExerciseDefinitionInput) throws {
        if let sets = input.defaultSets, sets < 1 {
            throw ValidationError.invalidSetCount
        }
        if let repetitions = input.defaultRepetitions, repetitions < 0 {
            throw ValidationError.negativeRepetitions
        }
        if let restSeconds = input.defaultRestSeconds, restSeconds < 0 {
            throw ValidationError.negativeRestTime
        }
    }

    private static func normalizedMetadata(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Other" : trimmed
    }

    private static func normalizedSecondaryMuscles(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.compactMap { value in
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            let normalized = normalizedName(trimmed)
            guard !trimmed.isEmpty, seen.insert(normalized).inserted else { return nil }
            return trimmed
        }
    }
}
