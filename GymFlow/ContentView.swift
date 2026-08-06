import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var audioPlayer: AudioPlayerService
    @State private var selectedTab: AppTab = .today
    @State private var seedingError: String?

    var body: some View {
        TabView(selection: $selectedTab) {
            TodayView()
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
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if audioPlayer.currentTrack != nil { MiniPlayerView() }
        }
        .task { seedInitialData() }
        .alert("Couldn’t Prepare GymFlow", isPresented: Binding(
            get: { seedingError != nil },
            set: { if !$0 { seedingError = nil } }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(seedingError ?? "An unknown data error occurred.")
        }
    }

    private func seedInitialData() {
        do {
            try SampleDataSeeder.seedIfNeeded(context: modelContext)
        } catch {
            seedingError = "Sample data could not be created. \(error.localizedDescription)"
        }
    }
}

enum AppTab: Hashable {
    case today
    case plans
    case history
    case music
}

#Preview {
    GymFlowPreview { ContentView() }
}
