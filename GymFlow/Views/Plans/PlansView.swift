import SwiftData
import SwiftUI

struct PlansView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutPlan.sortOrder) private var plans: [WorkoutPlan]
    @Query(sort: \Playlist.sortOrder) private var playlists: [Playlist]
    @State private var editorPresented = false
    @State private var editorPlan: WorkoutPlan?
    @State private var pendingDeletion: WorkoutPlan?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if plans.isEmpty {
                    ContentUnavailableView {
                        Label("No Workout Plans", systemImage: "list.bullet.clipboard")
                    } description: {
                        Text("Build a plan from the exercise library to get started.")
                    } actions: {
                        Button("Create Plan") { presentEditor(nil) }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    List {
                        ForEach(plans) { plan in
                            Button { presentEditor(plan) } label: {
                                PlanRow(
                                    plan: plan,
                                    playlistName: playlists.first(where: { $0.id == plan.assignedPlaylistID })?.name
                                )
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button("Edit", systemImage: "pencil") { presentEditor(plan) }
                                Button("Duplicate", systemImage: "plus.square.on.square") { duplicate(plan) }
                                Button("Delete", systemImage: "trash", role: .destructive) {
                                    pendingDeletion = plan
                                }
                            }
                            .swipeActions(edge: .trailing) {
                                Button("Delete", role: .destructive) { pendingDeletion = plan }
                                Button("Duplicate") { duplicate(plan) }.tint(.blue)
                            }
                        }
                        .onMove(perform: movePlans)
                    }
                }
            }
            .navigationTitle("Workout Plans")
            .toolbar {
                if !plans.isEmpty { EditButton() }
                Button("Create Plan", systemImage: "plus") { presentEditor(nil) }
                    .accessibilityLabel("Create workout plan")
            }
            .sheet(isPresented: $editorPresented) {
                NavigationStack { PlanEditorView(plan: editorPlan) }
                    .interactiveDismissDisabled()
            }
            .alert("Delete Workout Plan?", isPresented: Binding(
                get: { pendingDeletion != nil },
                set: { if !$0 { pendingDeletion = nil } }
            )) {
                Button("Delete", role: .destructive) { deletePendingPlan() }
                Button("Cancel", role: .cancel) { pendingDeletion = nil }
            } message: {
                Text("Past workout history will be kept. This action cannot be undone.")
            }
            .alert("Plan Error", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { }
            } message: { Text(errorMessage ?? "Unknown error") }
        }
    }

    private func presentEditor(_ plan: WorkoutPlan?) {
        editorPlan = plan
        editorPresented = true
    }

    private func duplicate(_ plan: WorkoutPlan) {
        let copy = WorkoutService.duplicate(plan: plan)
        copy.sortOrder = (plans.map(\.sortOrder).max() ?? -1) + 1
        modelContext.insert(copy)
        saveOrReport("The plan could not be duplicated.")
    }

    private func movePlans(from source: IndexSet, to destination: Int) {
        var reordered = plans
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, plan) in reordered.enumerated() { plan.sortOrder = index }
        saveOrReport("The new plan order could not be saved.")
    }

    private func deletePendingPlan() {
        guard let plan = pendingDeletion else { return }
        modelContext.delete(plan)
        pendingDeletion = nil
        saveOrReport("The plan could not be deleted.")
    }

    private func saveOrReport(_ prefix: String) {
        do { try modelContext.save() }
        catch { errorMessage = "\(prefix) \(error.localizedDescription)" }
    }
}

private struct PlanRow: View {
    let plan: WorkoutPlan
    let playlistName: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(plan.name).font(.headline)
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.tertiary)
            }
            Text("\(plan.exercises.count) exercises • about \(plan.expectedDurationMinutes) min")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if !plan.notes.isEmpty {
                Text(plan.notes).lineLimit(1).font(.footnote).foregroundStyle(.secondary)
            }
            if let playlistName {
                Label(playlistName, systemImage: "music.note.list")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

#Preview { GymFlowPreview { PlansView() } }
