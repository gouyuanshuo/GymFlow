import Foundation
import SwiftData

@MainActor
enum SampleDataSeeder {
    static let seedingKey = "hasSeededInitialGymFlowData"
    static let exerciseLibraryVersionKey = "exerciseLibrarySeedVersion"
    static let currentExerciseLibraryVersion = 1

    struct ExerciseSeed {
        let name: String
        let muscleGroup: String
        let equipment: String
        let defaultRestSeconds: Int?
        let defaultSets: Int?
        let defaultRepetitions: Int?

        init(
            name: String,
            muscleGroup: String,
            equipment: String,
            defaultRestSeconds: Int? = nil,
            defaultSets: Int? = nil,
            defaultRepetitions: Int? = nil
        ) {
            self.name = name
            self.muscleGroup = muscleGroup
            self.equipment = equipment
            self.defaultRestSeconds = defaultRestSeconds
            self.defaultSets = defaultSets
            self.defaultRepetitions = defaultRepetitions
        }
    }

    static let exerciseLibrary: [ExerciseSeed] = [
        .init(
            name: "Barbell Bench Press",
            muscleGroup: "Chest",
            equipment: "Barbell",
            defaultRestSeconds: 180,
            defaultSets: 4,
            defaultRepetitions: 8
        ),
        .init(name: "Incline Dumbbell Press", muscleGroup: "Chest", equipment: "Dumbbell"),
        .init(name: "Dumbbell Bench Press", muscleGroup: "Chest", equipment: "Dumbbell"),
        .init(name: "Cable Fly", muscleGroup: "Chest", equipment: "Cable"),
        .init(name: "Pec Deck", muscleGroup: "Chest", equipment: "Machine"),
        .init(name: "Lat Pulldown", muscleGroup: "Back", equipment: "Cable"),
        .init(name: "Pull-up", muscleGroup: "Back", equipment: "Bodyweight"),
        .init(name: "Seated Cable Row", muscleGroup: "Back", equipment: "Cable"),
        .init(name: "Barbell Row", muscleGroup: "Back", equipment: "Barbell"),
        .init(name: "One-arm Dumbbell Row", muscleGroup: "Back", equipment: "Dumbbell"),
        .init(name: "Dumbbell Shoulder Press", muscleGroup: "Shoulders", equipment: "Dumbbell"),
        .init(name: "Barbell Overhead Press", muscleGroup: "Shoulders", equipment: "Barbell"),
        .init(name: "Lateral Raise", muscleGroup: "Shoulders", equipment: "Dumbbell"),
        .init(name: "Rear Delt Fly", muscleGroup: "Shoulders", equipment: "Dumbbell"),
        .init(name: "Face Pull", muscleGroup: "Shoulders", equipment: "Cable"),
        .init(name: "Barbell Curl", muscleGroup: "Biceps", equipment: "Barbell"),
        .init(name: "Biceps Curl", muscleGroup: "Biceps", equipment: "Dumbbell"),
        .init(name: "Dumbbell Curl", muscleGroup: "Biceps", equipment: "Dumbbell"),
        .init(name: "Hammer Curl", muscleGroup: "Biceps", equipment: "Dumbbell"),
        .init(name: "Cable Curl", muscleGroup: "Biceps", equipment: "Cable"),
        .init(name: "Triceps Pushdown", muscleGroup: "Triceps", equipment: "Cable"),
        .init(name: "Overhead Triceps Extension", muscleGroup: "Triceps", equipment: "Dumbbell"),
        .init(name: "Skull Crusher", muscleGroup: "Triceps", equipment: "Barbell"),
        .init(name: "Close-Grip Bench Press", muscleGroup: "Triceps", equipment: "Barbell"),
        .init(name: "Barbell Squat", muscleGroup: "Quads", equipment: "Barbell"),
        .init(name: "Leg Press", muscleGroup: "Quads", equipment: "Machine"),
        .init(name: "Romanian Deadlift", muscleGroup: "Hamstrings", equipment: "Barbell"),
        .init(name: "Leg Extension", muscleGroup: "Quads", equipment: "Machine"),
        .init(name: "Leg Curl", muscleGroup: "Hamstrings", equipment: "Machine"),
        .init(name: "Bulgarian Split Squat", muscleGroup: "Quads", equipment: "Dumbbell"),
        .init(name: "Hip Thrust", muscleGroup: "Glutes", equipment: "Barbell"),
        .init(name: "Calf Raise", muscleGroup: "Calves", equipment: "Machine"),
        .init(name: "Plank", muscleGroup: "Core", equipment: "Bodyweight"),
        .init(name: "Hanging Leg Raise", muscleGroup: "Core", equipment: "Bodyweight"),
        .init(name: "Cable Crunch", muscleGroup: "Core", equipment: "Cable"),
        .init(name: "Treadmill", muscleGroup: "Cardio", equipment: "Cardio Machine"),
        .init(name: "Exercise Bike", muscleGroup: "Cardio", equipment: "Cardio Machine"),
        .init(name: "Rowing Machine", muscleGroup: "Cardio", equipment: "Cardio Machine")
    ]

    static func seedIfNeeded(context: ModelContext, defaults: UserDefaults = .standard) throws {
        let definitions = try ensureExerciseLibrary(context: context, defaults: defaults)
        let existingPlans = try context.fetch(FetchDescriptor<WorkoutPlan>())
        var plansToLink = existingPlans

        if !defaults.bool(forKey: seedingKey), existingPlans.isEmpty {
            let plans = samplePlans()
            plans.forEach(context.insert)
            plansToLink = plans
        }

        linkLegacyPlannedExercises(plans: plansToLink, definitions: definitions)

        try context.save()
        defaults.set(true, forKey: seedingKey)
        defaults.set(currentExerciseLibraryVersion, forKey: exerciseLibraryVersionKey)
    }

    static func linkLegacyPlannedExercises(
        plans: [WorkoutPlan],
        definitions: [ExerciseDefinition]
    ) {
        let definitionsByName = Dictionary(
            definitions.map { (ExerciseLibraryService.normalizedName($0.name), $0) },
            uniquingKeysWith: { first, _ in first }
        )
        for plan in plans {
            for exercise in plan.exercises where exercise.exerciseID == nil {
                let normalizedName = ExerciseLibraryService.normalizedName(exercise.exerciseNameSnapshot)
                guard let definition = definitionsByName[normalizedName] else { continue }
                exercise.exerciseID = definition.id
                exercise.exerciseNameSnapshot = definition.name
            }
        }
    }

    static func samplePlans() -> [WorkoutPlan] {
        [
            makePlan(name: "Chest and Arms", order: 0, exercises: [
                ("Barbell Bench Press", 4, 8, 60, 180),
                ("Incline Dumbbell Press", 4, 10, 20, 120),
                ("Cable Fly", 3, 12, 15, 90),
                ("Biceps Curl", 4, 10, 12, 90),
                ("Triceps Pushdown", 4, 12, 20, 90)
            ]),
            makePlan(name: "Back and Shoulders", order: 1, exercises: [
                ("Lat Pulldown", 4, 10, 55, 120),
                ("Seated Cable Row", 4, 10, 50, 120),
                ("One-arm Dumbbell Row", 4, 10, 24, 120),
                ("Dumbbell Shoulder Press", 4, 10, 16, 120),
                ("Lateral Raise", 4, 12, 7, 75)
            ]),
            makePlan(name: "Legs", order: 2, exercises: [
                ("Barbell Squat", 4, 8, 60, 180),
                ("Leg Press", 4, 10, 120, 180),
                ("Romanian Deadlift", 4, 10, 50, 150),
                ("Leg Curl", 4, 12, 35, 90)
            ])
        ]
    }

    private static func ensureExerciseLibrary(
        context: ModelContext,
        defaults: UserDefaults
    ) throws -> [ExerciseDefinition] {
        var definitions = try context.fetch(FetchDescriptor<ExerciseDefinition>())
        var definitionsByName = Dictionary(
            definitions.map { (ExerciseLibraryService.normalizedName($0.name), $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let shouldUpgradeBuiltIns = defaults.integer(forKey: exerciseLibraryVersionKey)
            < currentExerciseLibraryVersion
        let shouldInstallMissingBuiltIns = !defaults.bool(forKey: seedingKey)
            || shouldUpgradeBuiltIns

        for seed in exerciseLibrary {
            let normalizedName = ExerciseLibraryService.normalizedName(seed.name)
            if let existing = definitionsByName[normalizedName] {
                guard shouldUpgradeBuiltIns, !existing.isCustom else { continue }
                existing.muscleGroup = seed.muscleGroup
                existing.equipment = seed.equipment
                existing.defaultRestSeconds = seed.defaultRestSeconds
                existing.defaultSets = seed.defaultSets
                existing.defaultRepetitions = seed.defaultRepetitions
                existing.updatedAt = Date()
            } else {
                guard shouldInstallMissingBuiltIns else { continue }
                let definition = ExerciseDefinition(
                    name: seed.name,
                    muscleGroup: seed.muscleGroup,
                    equipment: seed.equipment,
                    defaultRestSeconds: seed.defaultRestSeconds,
                    defaultSets: seed.defaultSets,
                    defaultRepetitions: seed.defaultRepetitions
                )
                context.insert(definition)
                definitions.append(definition)
                definitionsByName[normalizedName] = definition
            }
        }
        return definitions
    }

    private static func makePlan(
        name: String,
        order: Int,
        exercises: [SamplePlanExercise]
    ) -> WorkoutPlan {
        let plannedExercises = exercises.enumerated().map { index, exercise in
            PlannedExercise(
                exerciseNameSnapshot: exercise.name,
                targetSets: exercise.sets,
                targetRepetitions: exercise.repetitions,
                targetWeight: exercise.weight,
                restSeconds: exercise.restSeconds,
                sortOrder: index
            )
        }
        return WorkoutPlan(name: name, sortOrder: order, exercises: plannedExercises)
    }
}

/// One line of a built-in sample plan.
///
/// A labelled tuple rather than a bare `(String, Int, Int, Double, Int)`, so the sample plan tables
/// above read as exercise data instead of as five positional numbers.
private typealias SamplePlanExercise = (
    name: String,
    sets: Int,
    repetitions: Int,
    weight: Double,
    restSeconds: Int
)
