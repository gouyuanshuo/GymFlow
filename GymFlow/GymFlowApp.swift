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
    @UIApplicationDelegateAdaptor(AppNotificationDelegate.self) private var appDelegate
    @StateObject private var audioPlayer = AudioPlayerService()
    private let modelContainer: ModelContainer?
    private let startupError: String?

    init() {
        do {
            let container = try GymFlowDataStore.makeContainer()
            modelContainer = container
            startupError = nil
            if #available(iOS 17.0, *) {
                WorkoutActivityIntentCoordinator.shared.configure(container: container)
            }
        } catch {
            modelContainer = nil
            startupError = error.localizedDescription
        }
    }

    var body: some Scene {
        WindowGroup {
            if let modelContainer {
                ContentView()
                    .environmentObject(audioPlayer)
                    .modelContainer(modelContainer)
            } else {
                ContentUnavailableView(
                    "GymFlow Couldn't Open",
                    systemImage: "exclamationmark.triangle",
                    description: Text(startupError ?? "The workout database is unavailable.")
                )
            }
        }
    }
}
