import SwiftData
import SwiftUI

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutPlan.sortOrder) private var plans: [WorkoutPlan]
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var sessions: [WorkoutSession]
    @AppStorage("selectedWorkoutPlanID") private var selectedPlanID = ""
    @State private var presentedSession: WorkoutSession?
    @State private var settingsPresented = false
    @State private var errorMessage: String?

    private var selectedPlan: WorkoutPlan? {
        plans.first(where: { $0.id.uuidString == selectedPlanID }) ?? plans.first
    }

    private var activeSession: WorkoutSession? {
        sessions.first(where: { $0.status == .active })
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
            .fullScreenCover(item: $presentedSession) { session in
                ActiveWorkoutView(session: session)
            }
            .alert("Workout Error", isPresented: errorBinding) {
                Button("OK", role: .cancel) { }
            } message: { Text(errorMessage ?? "Unknown error") }
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
            Button("Resume Workout") { presentedSession = session }
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .gymCard()
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }

    private func start(_ plan: WorkoutPlan) {
        let session = WorkoutService.makeSession(from: plan)
        modelContext.insert(session)
        do {
            try modelContext.save()
            selectedPlanID = plan.id.uuidString
            presentedSession = session
        } catch {
            modelContext.delete(session)
            errorMessage = "The workout could not be started. \(error.localizedDescription)"
        }
    }
}

#Preview { GymFlowPreview { TodayView() } }
