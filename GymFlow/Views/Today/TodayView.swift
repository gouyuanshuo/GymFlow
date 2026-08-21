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
    @AppStorage(PreferenceKey.selectedWorkoutPlanID) private var selectedPlanID = ""
    @AppStorage(PreferenceKey.activeWorkoutSessionID) private var activeWorkoutSessionID = ""
    @AppStorage(PreferenceKey.automaticallyPlayAssignedPlaylist) private var automaticallyPlayAssignedPlaylist = false
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
                        ActiveSessionCard(session: activeSession) {
                            presentWorkout(activeSession)
                        }
                    }

                    if let plan = selectedPlan {
                        SelectedPlanCard(
                            plan: plan,
                            allPlans: plans,
                            playlistName: assignedPlaylist(for: plan)?.name,
                            durationEstimate: WorkoutDurationEstimator.estimate(
                                for: plan,
                                sessions: sessions
                            ),
                            lastCompletedAt: lastCompletion(of: plan),
                            canStart: activeSession == nil,
                            onSelectPlan: { selectedPlanID = $0.id.uuidString },
                            onStart: { start(plan) }
                        )
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
            .errorAlert("Workout Error", message: $errorMessage)
            .onAppear { reconcileActiveSessionIdentity() }
        }
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

    private func lastCompletion(of plan: WorkoutPlan) -> Date? {
        sessions.first {
            $0.status == .completed && $0.workoutPlanID == plan.id
        }?.completedAt
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

/// The plan the user has lined up next, with the button that starts it.
private struct SelectedPlanCard: View {
    let plan: WorkoutPlan
    let allPlans: [WorkoutPlan]
    let playlistName: String?
    let durationEstimate: WorkoutDurationEstimate
    let lastCompletedAt: Date?
    /// False while another workout is still in progress; only one may run at a time.
    let canStart: Bool
    let onSelectPlan: (WorkoutPlan) -> Void
    let onStart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            if !plan.notes.isEmpty { Text(plan.notes).foregroundStyle(.secondary) }
            facts

            if let playlistName {
                Label(playlistName, systemImage: "music.note.list")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let lastCompletedAt {
                Text("Last completed \(lastCompletedAt, format: .relative(presentation: .named))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Button("Start Workout", systemImage: "play.fill", action: onStart)
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!canStart)
                .accessibilityHint(canStart
                    ? "Starts a new workout"
                    : "Finish or cancel the active workout first")
        }
        .gymCard()
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Selected Workout").font(.caption).foregroundStyle(.secondary)
                Text(plan.name).font(.title.bold())
            }
            Spacer()
            Menu {
                ForEach(allPlans) { option in
                    Button(option.name) { onSelectPlan(option) }
                }
            } label: {
                Label("Choose", systemImage: "arrow.up.arrow.down.circle")
                    .labelStyle(.iconOnly)
                    .font(.title2)
            }
            .accessibilityLabel("Choose workout plan")
        }
    }

    private var facts: some View {
        HStack(spacing: 24) {
            Label("\(plan.exercises.count) exercises", systemImage: "list.number")
            Label("About \(durationEstimate.roundedMinutes) min", systemImage: "clock")
                .accessibilityIdentifier("workout-duration-estimate")
                .accessibilityValue(durationEstimate.source == .history
                    ? "Based on \(durationEstimate.sampleCount) recent workouts"
                    : "Based on plan targets")
        }
        .font(.subheadline)
    }
}

/// The banner offering to return to a workout that is already under way.
private struct ActiveSessionCard: View {
    let session: WorkoutSession
    let onResume: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Workout in Progress", systemImage: "bolt.heart.fill")
                .font(.headline)
                .foregroundStyle(.tint)
            Text(session.planNameSnapshot).font(.title3.bold())
            Text("Started \(session.startedAt, format: .relative(presentation: .named))")
                .foregroundStyle(.secondary)
            Button("Resume Workout", action: onResume)
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .gymCard()
    }
}

#Preview { GymFlowPreview { TodayView() } }
