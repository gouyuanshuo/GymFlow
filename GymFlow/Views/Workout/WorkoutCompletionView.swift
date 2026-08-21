import SwiftData
import SwiftUI

struct WorkoutCompletionView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var allSessions: [WorkoutSession]
    /// `@Bindable` so the notes field binds straight to the model instead of through a
    /// hand-written `Binding(get:set:)`.
    @Bindable var session: WorkoutSession
    let onDone: () -> Void
    @State private var errorMessage: String?
    @State private var sharePresentation: WorkoutSharePresentation?

    private var personalBestEvents: [ExercisePREvent] {
        ExercisePerformanceService.personalBestEvents(in: session, sessions: allSessions)
    }

    var body: some View {
        let newPersonalBestEvents = personalBestEvents
        // Read once: the four metric tiles below would otherwise each rescan every logged set.
        let totals = session.totals
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 70))
                        .foregroundStyle(.green)
                        .accessibilityHidden(true)
                    VStack(spacing: 6) {
                        Text("Workout Complete").font(.largeTitle.bold())
                        Text(session.planNameSnapshot).font(.title3).foregroundStyle(.secondary)
                    }

                    LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 12) {
                        SummaryMetric(title: "Duration", value: GymFlowFormatters.duration(session.duration), icon: "clock")
                        SummaryMetric(title: "Exercises", value: "\(totals.exerciseCount)", icon: "dumbbell")
                        SummaryMetric(title: "Sets", value: "\(totals.setCount)", icon: "checklist")
                        SummaryMetric(title: "Repetitions", value: "\(totals.repetitions)", icon: "repeat")
                    }
                    SummaryMetric(
                        title: "Training Volume",
                        value: "\(GymFlowFormatters.weight(totals.volume)) kg",
                        icon: "scalemass"
                    )
                    if let playlistName = session.playlistNameSnapshot {
                        SummaryMetric(title: "Workout Playlist", value: playlistName, icon: "music.note.list")
                    }

                    if !newPersonalBestEvents.isEmpty {
                        WorkoutPersonalBestCelebration(
                            events: Array(newPersonalBestEvents.prefix(4))
                        )
                    }

                    Button {
                        prepareShare()
                    } label: {
                        Label("Share Workout", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .accessibilityIdentifier("share-completed-workout")

                    VStack(alignment: .leading) {
                        Text("Workout Notes").font(.headline)
                        TextEditor(text: $session.notes)
                            .frame(minHeight: 100)
                            .scrollContentBackground(.hidden)
                            .accessibilityLabel("Workout notes")
                    }
                    .gymCard()

                    Button("Save and Return to Today") { saveAndClose() }
                        .buttonStyle(PrimaryButtonStyle())
                }
                .padding()
            }
            .navigationBarBackButtonHidden()
            .sheet(item: $sharePresentation) { presentation in
                NavigationStack {
                    WorkoutSharePreviewView(summary: presentation.summary)
                }
            }
            .errorAlert("Workout Error", message: $errorMessage)
        }
    }

    private func prepareShare() {
        do {
            sharePresentation = WorkoutSharePresentation(
                summary: try WorkoutShareSummaryBuilder.build(
                    from: session,
                    sessions: allSessions
                )
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func saveAndClose() {
        do {
            try modelContext.save()
            onDone()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct WorkoutPersonalBestCelebration: View {
    let events: [ExercisePREvent]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("New Personal Best", systemImage: "sparkles")
                .font(.headline.weight(.bold))
                .foregroundStyle(.orange)

            ForEach(events) { event in
                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(event.record.exerciseName)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                        Spacer(minLength: 8)
                        Text(event.primaryType.title)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.orange)
                    }
                    Text(event.record.setDescription)
                        .font(.title3.monospacedDigit().weight(.bold))
                    if let metricDescription = event.metricDescription {
                        Text(metricDescription)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .gymCard()
        .overlay(alignment: .topTrailing) {
            Image(systemName: "trophy.fill")
                .font(.title2)
                .foregroundStyle(.orange.opacity(0.7))
                .padding(16)
                .accessibilityHidden(true)
        }
        .accessibilityIdentifier("workout-personal-bests")
    }
}

struct SummaryMetric: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon).foregroundStyle(.tint)
            Text(value).font(.title3.bold()).minimumScaleFactor(0.7)
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 90)
        .gymCard()
    }
}
