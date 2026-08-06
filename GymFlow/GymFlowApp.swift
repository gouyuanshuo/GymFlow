//
//  GymFlowApp.swift
//  GymFlow
//
//  Created by Yuanshuo Gou on 6/8/2026.
//

import SwiftData
import SwiftUI

@main
struct GymFlowApp: App {
    @StateObject private var audioPlayer = AudioPlayerService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(audioPlayer)
        }
        .modelContainer(for: [
            WorkoutPlan.self,
            PlannedExercise.self,
            ExerciseDefinition.self,
            WorkoutSession.self,
            ExerciseRecord.self,
            WorkoutSetRecord.self,
            ImportedTrack.self
        ])
    }
}
