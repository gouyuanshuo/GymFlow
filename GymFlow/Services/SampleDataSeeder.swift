import Foundation
import SwiftData

@MainActor
enum SampleDataSeeder {
    static let seedingKey = "hasSeededInitialGymFlowData"

    struct ExerciseSeed {
        let name: String
        let muscleGroup: String
        let equipment: String
    }

    static let exerciseLibrary: [ExerciseSeed] = [
        .init(name: "Barbell Bench Press", muscleGroup: "Chest", equipment: "Barbell"),
        .init(name: "Incline Dumbbell Press", muscleGroup: "Chest", equipment: "Dumbbells"),
        .init(name: "Cable Fly", muscleGroup: "Chest", equipment: "Cable"),
        .init(name: "Lat Pulldown", muscleGroup: "Back", equipment: "Cable"),
        .init(name: "Seated Cable Row", muscleGroup: "Back", equipment: "Cable"),
        .init(name: "One-arm Dumbbell Row", muscleGroup: "Back", equipment: "Dumbbell"),
        .init(name: "Dumbbell Shoulder Press", muscleGroup: "Shoulders", equipment: "Dumbbells"),
        .init(name: "Lateral Raise", muscleGroup: "Shoulders", equipment: "Dumbbells"),
        .init(name: "Barbell Squat", muscleGroup: "Legs", equipment: "Barbell"),
        .init(name: "Leg Press", muscleGroup: "Legs", equipment: "Machine"),
        .init(name: "Romanian Deadlift", muscleGroup: "Hamstrings", equipment: "Barbell"),
        .init(name: "Leg Curl", muscleGroup: "Hamstrings", equipment: "Machine"),
        .init(name: "Biceps Curl", muscleGroup: "Arms", equipment: "Dumbbells"),
        .init(name: "Triceps Pushdown", muscleGroup: "Arms", equipment: "Cable")
    ]

    static func seedIfNeeded(context: ModelContext, defaults: UserDefaults = .standard) throws {
        guard !defaults.bool(forKey: seedingKey) else { return }

        var descriptor = FetchDescriptor<ExerciseDefinition>()
        descriptor.fetchLimit = 1
        let hasExercises = try !context.fetch(descriptor).isEmpty

        if !hasExercises {
            exerciseLibrary.forEach { seed in
                context.insert(ExerciseDefinition(
                    name: seed.name,
                    muscleGroup: seed.muscleGroup,
                    equipment: seed.equipment
                ))
            }
        }

        var planDescriptor = FetchDescriptor<WorkoutPlan>()
        planDescriptor.fetchLimit = 1
        if try context.fetch(planDescriptor).isEmpty {
            samplePlans().forEach(context.insert)
        }

        try context.save()
        defaults.set(true, forKey: seedingKey)
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

    private static func makePlan(
        name: String,
        order: Int,
        exercises: [(String, Int, Int, Double, Int)]
    ) -> WorkoutPlan {
        let plannedExercises = exercises.enumerated().map { index, values in
            PlannedExercise(
                exerciseNameSnapshot: values.0,
                targetSets: values.1,
                targetRepetitions: values.2,
                targetWeight: values.3,
                restSeconds: values.4,
                sortOrder: index
            )
        }
        return WorkoutPlan(name: name, sortOrder: order, exercises: plannedExercises)
    }
}
