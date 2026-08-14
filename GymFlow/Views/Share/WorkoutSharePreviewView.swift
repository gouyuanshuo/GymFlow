import SwiftUI

struct WorkoutSharePresentation: Identifiable {
    let id = UUID()
    let summary: WorkoutShareSummary
}

struct WorkoutSharePreviewView: View {
    @Environment(\.dismiss) private var dismiss
    let summary: WorkoutShareSummary

    @State private var backgroundSelection: WorkoutShareBackgroundSelection
    @State private var shareImage: UIImage?
    @State private var shareSheetPresented = false
    @State private var isRendering = false
    @State private var errorMessage: String?

    init(summary: WorkoutShareSummary) {
        self.summary = summary
        let count = max(WorkoutShareBackground.allCases.count, 1)
        _backgroundSelection = State(
            initialValue: WorkoutShareBackgroundSelection(
                initialIndex: Int.random(in: 0..<count)
            )
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                WorkoutShareCardView(
                    summary: summary,
                    background: backgroundSelection.selected
                )
                .frame(maxWidth: 360)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .shadow(color: .black.opacity(0.18), radius: 18, y: 8)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("workout-share-card")

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Background")
                            .font(.headline)
                        Spacer()
                        Button {
                            randomizeBackground()
                        } label: {
                            Label("Randomize", systemImage: "shuffle")
                        }
                        .accessibilityIdentifier("randomize-share-background")
                    }

                    ShareBackgroundPicker(
                        backgrounds: backgroundSelection.available,
                        selected: backgroundSelection.selected,
                        onSelect: selectBackground
                    )
                }
            }
            .padding()
        }
        .accessibilityIdentifier("workout-share-preview-scroll")
        .safeAreaInset(edge: .bottom) {
            shareAction
        }
        .navigationTitle("Share Preview")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
            }
        }
        .sheet(isPresented: $shareSheetPresented, onDismiss: clearRenderedImage) {
            if let shareImage {
                ActivityShareSheet(image: shareImage, workoutName: summary.workoutName)
                    .ignoresSafeArea()
            }
        }
        .alert("Couldn’t Share Workout", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? WorkoutShareError.imageRenderFailed.localizedDescription)
        }
    }

    private var shareAction: some View {
        VStack(spacing: 0) {
            Divider()
            Button {
                renderAndShare()
            } label: {
                if isRendering {
                    HStack {
                        ProgressView()
                        Text("Creating Image…")
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(isRendering)
            .accessibilityIdentifier("share-workout-image")
            .padding()
        }
        .background(.bar)
    }

    private func selectBackground(_ background: WorkoutShareBackground) {
        backgroundSelection.select(background)
        shareImage = nil
    }

    private func randomizeBackground() {
        let alternativeCount = max(backgroundSelection.available.count - 1, 1)
        backgroundSelection.randomize(index: Int.random(in: 0..<alternativeCount))
        shareImage = nil
    }

    private func renderAndShare() {
        guard !isRendering else { return }
        isRendering = true
        errorMessage = nil

        Task { @MainActor in
            await Task.yield()
            do {
                let image = try WorkoutShareRenderer.render(
                    summary: summary,
                    background: backgroundSelection.selected
                )
                shareImage = image
                shareSheetPresented = true
            } catch {
                errorMessage = error.localizedDescription
            }
            isRendering = false
        }
    }

    private func clearRenderedImage() {
        shareImage = nil
    }
}

#Preview("Workout Share Preview") {
    NavigationStack {
        WorkoutSharePreviewView(
            summary: WorkoutShareSummary(
                workoutName: "Friday Strength Session With A Very Long Workout Name",
                date: Date(),
                duration: 7_620,
                exerciseCount: 8,
                setCount: 27,
                repetitionCount: 214,
                trainingVolume: 38_750,
                exerciseHighlights: [
                    .init(name: "Barbell Back Squat", weight: 120, repetitions: 5, exerciseVolume: 3_000, sortOrder: 0),
                    .init(name: "Romanian Deadlift", weight: 100, repetitions: 8, exerciseVolume: 2_400, sortOrder: 1),
                    .init(name: "Bulgarian Split Squat", weight: 28, repetitions: 10, exerciseVolume: 1_120, sortOrder: 2)
                ]
            )
        )
    }
}
