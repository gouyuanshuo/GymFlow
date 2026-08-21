import SwiftUI

/// The shareable poster summarising one finished workout.
///
/// The card is composed of independent section views stacked top to bottom. It is laid out against
/// a fixed design size and scaled to fit its container, so the scale factor and palette are put
/// into the environment once here rather than passed down through every section.
struct WorkoutShareCardView: View {
    let summary: WorkoutShareSummary
    let background: WorkoutShareBackground

    var body: some View {
        GeometryReader { geometry in
            let style = WorkoutShareCardStyle(
                scale: WorkoutShareCardStyle.scale(fitting: geometry.size),
                background: background
            )

            ZStack {
                WorkoutShareBackgroundView(background: background)
                content(style: style)
            }
            .workoutShareCardStyle(style)
            .foregroundStyle(background.foregroundColor)
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
        }
        .aspectRatio(
            WorkoutShareCardStyle.designSize.width / WorkoutShareCardStyle.designSize.height,
            contentMode: .fit
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(summary.accessibilityDescription)
    }

    private func content(style: WorkoutShareCardStyle) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ShareCardBrandHeader()
            Spacer(minLength: style.length(24))
            ShareCardWorkoutHeader(workoutName: summary.displayWorkoutName, date: summary.date)
            Spacer(minLength: style.length(20))
            ShareCardHeroPanel()
            Spacer(minLength: style.length(18))
            ShareCardMetricsPanel(summary: summary)
            Spacer(minLength: style.length(18))
            ShareCardHighlightsPanel(
                exerciseCount: summary.exerciseCount,
                highlights: summary.exerciseHighlights
            )

            if let personalBest = summary.personalBestHighlight {
                Spacer(minLength: style.length(16))
                ShareCardPersonalBestPanel(personalBest: personalBest)
            }

            Spacer(minLength: style.length(18))
            ShareCardFooter()
        }
        .padding(.horizontal, style.length(28))
        .padding(.vertical, style.length(30))
    }
}

#Preview("Workout Share Card") {
    WorkoutShareCardView(
        summary: WorkoutShareSummary(
            workoutName: "Chest + Arms",
            date: Date(),
            duration: 4_680,
            exerciseCount: 5,
            setCount: 19,
            repetitionCount: 168,
            trainingVolume: 12_840,
            exerciseHighlights: [
                .init(name: "Barbell Bench Press", weight: 70, repetitions: 8, exerciseVolume: 2_100, sortOrder: 0),
                .init(name: "Incline Dumbbell Press", weight: 24, repetitions: 10, exerciseVolume: 960, sortOrder: 1),
                .init(name: "Cable Fly", weight: 20, repetitions: 12, exerciseVolume: 720, sortOrder: 2)
            ],
            personalBestHighlight: .init(
                exerciseName: "Barbell Bench Press",
                typeTitle: "Weight PR",
                setDescription: "80 kg × 5",
                metricDescription: nil
            )
        ),
        background: .electricBlue
    )
    .frame(width: 393, height: 852)
}
