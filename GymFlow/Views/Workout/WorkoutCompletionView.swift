import SwiftData
import SwiftUI

struct WorkoutCompletionView: View {
    @Environment(\.modelContext) private var modelContext
    let session: WorkoutSession
    let onDone: () -> Void
    @State private var errorMessage: String?

    var body: some View {
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
                        SummaryMetric(title: "Exercises", value: "\(session.completedExerciseCount)", icon: "dumbbell")
                        SummaryMetric(title: "Sets", value: "\(session.completedSetCount)", icon: "checklist")
                        SummaryMetric(title: "Repetitions", value: "\(session.totalRepetitions)", icon: "repeat")
                    }
                    SummaryMetric(
                        title: "Training Volume",
                        value: "\(GymFlowFormatters.weight(session.trainingVolume)) kg",
                        icon: "scalemass"
                    )

                    VStack(alignment: .leading) {
                        Text("Workout Notes").font(.headline)
                        TextEditor(text: Binding(
                            get: { session.notes }, set: { session.notes = $0 }
                        ))
                        .frame(minHeight: 100)
                        .scrollContentBackground(.hidden)
                    }
                    .gymCard()

                    Button("Save and Return to Today") { saveAndClose() }
                        .buttonStyle(PrimaryButtonStyle())
                }
                .padding()
            }
            .navigationBarBackButtonHidden()
            .alert("Couldn’t Save Notes", isPresented: Binding(
                get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
            )) { Button("OK", role: .cancel) { } } message: { Text(errorMessage ?? "Unknown error") }
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
