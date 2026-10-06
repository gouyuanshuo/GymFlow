import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var sessions: [WorkoutSession]
    @AppStorage(PreferenceKey.activeWorkoutSessionID) private var activeWorkoutSessionID = ""
    @State private var selectedTab: AppTab = .today
    @State private var isWorkoutPresented = false
    @State private var nowPlayingPresentation = NowPlayingPresentationState()
    @State private var seedingError: String?

    var body: some View {
        rootTabs
            .background { AudioLibrarySynchronizer() }
            .sheet(isPresented: nowPlayingPresentedBinding) {
                NowPlayingView()
            }
            .task {
                seedInitialData()
                reconcileWorkoutActivities()
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    reconcileWorkoutActivities()
                }
            }
            .errorAlert("Couldn’t Prepare GymFlow", message: $seedingError)
    }

    @ViewBuilder
    private var rootTabs: some View {
        if #available(iOS 26.0, *) {
            tabs
                .tabViewBottomAccessory {
                    GlobalMiniPlayerAccessory(
                        isWorkoutPresented: isWorkoutPresented,
                        isNowPlayingPresented: nowPlayingPresentation.isPresented
                    ) { nowPlayingPresentation.present() }
                }
        } else {
            tabs
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    GlobalMiniPlayerAccessory(
                        isWorkoutPresented: isWorkoutPresented,
                        isNowPlayingPresented: nowPlayingPresentation.isPresented
                    ) { nowPlayingPresentation.present() }
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

    private var nowPlayingPresentedBinding: Binding<Bool> {
        Binding(
            get: { nowPlayingPresentation.isPresented },
            set: { nowPlayingPresentation.updateSystemPresentation($0) }
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

/// Syncs the audio library without observing playback in the root view.
private struct AudioLibrarySynchronizer: View {
    @EnvironmentObject private var audioPlayer: AudioPlayerService
    @Query(sort: \ImportedTrack.sortOrder) private var tracks: [ImportedTrack]

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .task { audioPlayer.synchronizeLibrary(tracks) }
            .onChange(of: tracks.map(\.id)) { _, _ in
                audioPlayer.synchronizeLibrary(tracks)
            }
    }
}

private struct GlobalMiniPlayerAccessory: View {
    @EnvironmentObject private var audioPlayer: AudioPlayerService
    let isWorkoutPresented: Bool
    let isNowPlayingPresented: Bool
    let openNowPlaying: () -> Void

    var body: some View {
        if MiniPlayerPresentationPolicy.showsGlobalPlayer(
            hasLoadedTrack: audioPlayer.currentTrack != nil,
            isWorkoutPresented: isWorkoutPresented,
            isNowPlayingPresented: isNowPlayingPresented
        ) {
            MiniPlayerView(onOpenNowPlaying: openNowPlaying)
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
