import SwiftData
import SwiftUI

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var sessions: [WorkoutSession]
    @State private var presentation = HistoryPresentation.list
    @State private var searchText = ""
    @State private var pendingDeletion: WorkoutSession?
    @State private var errorMessage: String?

    private var completedSessions: [WorkoutSession] {
        sessions.filter { session in
            guard session.status == .completed else { return false }
            guard !searchText.isEmpty else { return true }
            return session.planNameSnapshot.localizedCaseInsensitiveContains(searchText)
                || session.exerciseRecords.contains {
                    $0.exerciseNameSnapshot.localizedCaseInsensitiveContains(searchText)
                }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("History presentation", selection: $presentation) {
                    ForEach(HistoryPresentation.allCases) { value in
                        Text(value.title).tag(value)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                if presentation == .list {
                    historyList
                        .searchable(text: $searchText, prompt: "Plan or exercise")
                } else {
                    WorkoutCalendarView(sessions: sessions)
                }
            }
            .navigationTitle("History")
            .navigationDestination(for: WorkoutSession.self) { session in
                WorkoutHistoryDetailView(session: session)
            }
            .alert("Delete Workout History?", isPresented: $pendingDeletion.isPresent()) {
                Button("Delete", role: .destructive) { deletePending() }
                Button("Cancel", role: .cancel) { pendingDeletion = nil }
            } message: { Text("This completed workout cannot be recovered.") }
            .errorAlert("History Error", message: $errorMessage)
        }
    }

    @ViewBuilder
    private var historyList: some View {
        if completedSessions.isEmpty {
            ContentUnavailableView(
                searchText.isEmpty ? "No Workout History" : "No Matches",
                systemImage: "clock.arrow.circlepath",
                description: Text(searchText.isEmpty
                    ? "Finished workouts will appear here."
                    : "Try another plan or exercise name.")
            )
        } else {
            List(completedSessions) { session in
                NavigationLink(value: session) {
                    HistoryRow(session: session)
                }
                .accessibilityIdentifier("history-workout-row")
                .swipeActions {
                    Button("Delete", role: .destructive) { pendingDeletion = session }
                }
            }
        }
    }

    private func deletePending() {
        guard let session = pendingDeletion else { return }
        modelContext.delete(session)
        pendingDeletion = nil
        do { try modelContext.save() }
        catch { errorMessage = "The workout could not be deleted. \(error.localizedDescription)" }
    }
}

private enum HistoryPresentation: String, CaseIterable, Identifiable {
    case list
    case calendar

    var id: String { rawValue }
    var title: String { self == .list ? "List" : "Calendar" }
}

private struct HistoryRow: View {
    let session: WorkoutSession

    var body: some View {
        // Read once per row: the three figures below all come from the same scan of the workout.
        let totals = session.totals

        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(session.planNameSnapshot).font(.headline)
                Spacer()
                Text(session.startedAt, format: .dateTime.month(.abbreviated).day().year())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text("\(GymFlowFormatters.duration(session.duration)) • \(totals.exerciseCount) exercises • \(totals.setCount) sets")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("\(GymFlowFormatters.weight(totals.volume)) kg volume")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 3)
    }
}

#Preview { GymFlowPreview { HistoryView() } }
