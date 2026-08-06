import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var audioPlayer: AudioPlayerService
    @Query(sort: \ImportedTrack.sortOrder) private var tracks: [ImportedTrack]
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var sessions: [WorkoutSession]
    @AppStorage("activeWorkoutSessionID") private var activeWorkoutSessionID = ""
    @State private var selectedTab: AppTab = .today
    @State private var isWorkoutPresented = false
    @State private var seedingError: String?

    var body: some View {
        rootTabs
            .task {
                seedInitialData()
                audioPlayer.synchronizeLibrary(tracks)
                reconcileWorkoutActivities()
            }
            .onChange(of: tracks.map(\.id)) { _, _ in
                audioPlayer.synchronizeLibrary(tracks)
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    reconcileWorkoutActivities()
                }
            }
            .alert("Couldn’t Prepare GymFlow", isPresented: Binding(
                get: { seedingError != nil },
                set: { if !$0 { seedingError = nil } }
            )) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(seedingError ?? "An unknown data error occurred.")
            }
    }

    @ViewBuilder
    private var rootTabs: some View {
        if #available(iOS 26.0, *) {
            tabs
                .tabViewBottomAccessory {
                    if showsGlobalMiniPlayer { MiniPlayerView() }
                }
        } else {
            tabs
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    if showsGlobalMiniPlayer { MiniPlayerView() }
                }
        }
    }

    private var tabs: some View {
        TabView(selection: $selectedTab) {
            TodayView { isWorkoutPresented = $0 }
                .tag(AppTab.today)
                .tabItem { Label("Today", systemImage: "sun.max.fill") }

            PlansView()
                .tag(AppTab.plans)
                .tabItem { Label("Plans", systemImage: "list.bullet.clipboard") }

            HistoryView()
                .tag(AppTab.history)
                .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }

            MusicLibraryView()
                .tag(AppTab.music)
                .tabItem { Label("Music", systemImage: "music.note.list") }

            SettingsView(showsDoneButton: false)
                .tag(AppTab.settings)
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }

    private var showsGlobalMiniPlayer: Bool {
        MiniPlayerPresentationPolicy.showsGlobalPlayer(
            hasLoadedTrack: audioPlayer.currentTrack != nil,
            isWorkoutPresented: isWorkoutPresented
        )
    }

    private func seedInitialData() {
        do {
            try SampleDataSeeder.seedIfNeeded(context: modelContext)
        } catch {
            seedingError = "Sample data could not be created. \(error.localizedDescription)"
        }
    }

    private func reconcileWorkoutActivities(now: Date = Date()) {
        do {
            let selectedSessionID = try LiveActivityManager.shared.reconcilePersistedWorkouts(
                sessions,
                preferredSessionID: UUID(uuidString: activeWorkoutSessionID),
                modelContext: modelContext,
                now: now
            )
            activeWorkoutSessionID = selectedSessionID?.uuidString ?? ""
        } catch {
            seedingError = "An interrupted workout could not be reconciled. \(error.localizedDescription)"
        }
    }
}

enum AppTab: Hashable {
    case today
    case plans
    case history
    case music
    case settings
}

#Preview {
    GymFlowPreview { ContentView() }
}
