import SwiftData
import SwiftUI

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var audioPlayer: AudioPlayerService
    @Query(sort: \WorkoutPlan.sortOrder) private var plans: [WorkoutPlan]
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var sessions: [WorkoutSession]
    @Query(sort: \Playlist.sortOrder) private var playlists: [Playlist]
    @Query private var playlistMemberships: [PlaylistTrack]
    @Query(sort: \ImportedTrack.sortOrder) private var tracks: [ImportedTrack]
    @AppStorage("selectedWorkoutPlanID") private var selectedPlanID = ""
    @AppStorage("activeWorkoutSessionID") private var activeWorkoutSessionID = ""
    @AppStorage("automaticallyPlayAssignedPlaylist") private var automaticallyPlayAssignedPlaylist = false
    @State private var presentedSession: WorkoutSession?
    @State private var settingsPresented = false
    @State private var errorMessage: String?
    private let onWorkoutPresentationChanged: (Bool) -> Void

    init(onWorkoutPresentationChanged: @escaping (Bool) -> Void = { _ in }) {
        self.onWorkoutPresentationChanged = onWorkoutPresentationChanged
    }

    private var selectedPlan: WorkoutPlan? {
        plans.first(where: { $0.id.uuidString == selectedPlanID }) ?? plans.first
    }

    private var activeSession: WorkoutSession? {
        sessions.first(where: {
            $0.status == .active && $0.id.uuidString == activeWorkoutSessionID
        }) ?? sessions.first(where: { $0.status == .active })
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(Date.now, format: .dateTime.weekday(.wide).month(.wide).day())
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.secondary)

                    if let activeSession {
                        activeSessionCard(activeSession)
                    }

                    if let plan = selectedPlan {
                        planCard(plan)
                    } else {
                        ContentUnavailableView(
                            "No Workout Plans",
                            systemImage: "figure.strengthtraining.traditional",
                            description: Text("Create a plan in the Plans tab to begin.")
                        )
                        .frame(maxWidth: .infinity, minHeight: 320)
                    }
                }
                .padding()
            }
            .navigationTitle("Today")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Settings", systemImage: "gearshape") { settingsPresented = true }
                        .accessibilityLabel("Open settings")
                }
            }
            .sheet(isPresented: $settingsPresented) { SettingsView() }
            .fullScreenCover(item: $presentedSession, onDismiss: {
                onWorkoutPresentationChanged(false)
            }) { session in
                ActiveWorkoutView(session: session)
            }
            .alert("Workout Error", isPresented: errorBinding) {
                Button("OK", role: .cancel) { }
            } message: { Text(errorMessage ?? "Unknown error") }
            .onAppear { reconcileActiveSessionIdentity() }
        }
    }

    @ViewBuilder
    private func planCard(_ plan: WorkoutPlan) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Selected Workout").font(.caption).foregroundStyle(.secondary)
                    Text(plan.name).font(.title.bold())
                }
                Spacer()
                Menu {
                    ForEach(plans) { option in
                        Button(option.name) { selectedPlanID = option.id.uuidString }
                    }
                } label: {
                    Label("Choose", systemImage: "arrow.up.arrow.down.circle")
                        .labelStyle(.iconOnly)
                        .font(.title2)
                }
                .accessibilityLabel("Choose workout plan")
            }

            if !plan.notes.isEmpty { Text(plan.notes).foregroundStyle(.secondary) }

            HStack(spacing: 24) {
                Label("\(plan.exercises.count) exercises", systemImage: "list.number")
                Label("About \(plan.expectedDurationMinutes) min", systemImage: "clock")
            }
            .font(.subheadline)

            if let playlist = assignedPlaylist(for: plan) {
                Label(playlist.name, systemImage: "music.note.list")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let last = sessions.first(where: {
                $0.status == .completed && $0.workoutPlanID == plan.id
            })?.completedAt {
                Text("Last completed \(last, format: .relative(presentation: .named))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Button("Start Workout", systemImage: "play.fill") { start(plan) }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(activeSession != nil)
                .accessibilityHint(activeSession == nil ? "Starts a new workout" : "Finish or cancel the active workout first")
        }
        .gymCard()
    }

    @ViewBuilder
    private func activeSessionCard(_ session: WorkoutSession) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Workout in Progress", systemImage: "bolt.heart.fill")
                .font(.headline)
                .foregroundStyle(.tint)
            Text(session.planNameSnapshot).font(.title3.bold())
            Text("Started \(session.startedAt, format: .relative(presentation: .named))")
                .foregroundStyle(.secondary)
            Button("Resume Workout") { presentWorkout(session) }
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .gymCard()
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }

    private func start(_ plan: WorkoutPlan) {
        let playlist = assignedPlaylist(for: plan)
        let session = WorkoutService.makeSession(
            from: plan,
            previousSessions: sessions,
            playlist: playlist
        )
        modelContext.insert(session)
        do {
            try modelContext.save()
            selectedPlanID = plan.id.uuidString
            activeWorkoutSessionID = session.id.uuidString
            if let playlist {
                audioPlayer.setQueue(
                    PlaylistService.orderedTracks(
                        for: playlist.id,
                        memberships: playlistMemberships,
                        tracks: tracks
                    ),
                    name: playlist.name,
                    playlistID: playlist.id,
                    shuffled: false,
                    autoplay: automaticallyPlayAssignedPlaylist
                )
            }
            presentWorkout(session)
        } catch {
            modelContext.delete(session)
            errorMessage = "The workout could not be started. \(error.localizedDescription)"
        }
    }

    private func assignedPlaylist(for plan: WorkoutPlan) -> Playlist? {
        guard let playlistID = plan.assignedPlaylistID else { return nil }
        return playlists.first(where: { $0.id == playlistID })
    }

    private func presentWorkout(_ session: WorkoutSession) {
        onWorkoutPresentationChanged(true)
        presentedSession = session
    }

    private func reconcileActiveSessionIdentity() {
        if let activeSession {
            activeWorkoutSessionID = activeSession.id.uuidString
        } else {
            activeWorkoutSessionID = ""
        }
    }
}

#Preview { GymFlowPreview { TodayView() } }
