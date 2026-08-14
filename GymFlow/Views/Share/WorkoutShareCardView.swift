import SwiftUI

struct WorkoutShareCardView: View {
    let summary: WorkoutShareSummary
    let background: WorkoutShareBackground

    var body: some View {
        GeometryReader { geometry in
            let scale = min(geometry.size.width / 360, geometry.size.height / 450)

            ZStack {
                WorkoutShareBackgroundView(background: background)

                VStack(alignment: .leading, spacing: 0) {
                    brandHeader(scale: scale)
                    Spacer(minLength: 10 * scale)
                    workoutHeader(scale: scale)
                    Spacer(minLength: 13 * scale)
                    metricsPanel(scale: scale)
                    Spacer(minLength: 12 * scale)
                    highlightsPanel(scale: scale)
                    Spacer(minLength: 10 * scale)
                    footer(scale: scale)
                }
                .padding(22 * scale)
            }
            .foregroundStyle(background.foregroundColor)
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
        }
        .aspectRatio(4.0 / 5.0, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(summary.accessibilityDescription)
    }

    private func brandHeader(scale: CGFloat) -> some View {
        HStack(spacing: 7 * scale) {
            Image(systemName: "bolt.heart.fill")
                .font(.system(size: 12 * scale, weight: .bold))
            Text("GYMFLOW")
                .font(.system(size: 11 * scale, weight: .black, design: .rounded))
                .tracking(1.6 * scale)
            Spacer()
            Text("WORKOUT RESULT")
                .font(.system(size: 8 * scale, weight: .bold, design: .rounded))
                .tracking(1.0 * scale)
                .foregroundStyle(background.secondaryForegroundColor)
        }
    }

    private func workoutHeader(scale: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 5 * scale) {
            Text(summary.displayWorkoutName.uppercased())
                .font(.system(size: 27 * scale, weight: .black, design: .rounded))
                .tracking(-0.7 * scale)
                .lineLimit(2)
                .minimumScaleFactor(0.72)
                .fixedSize(horizontal: false, vertical: true)

            Text(summary.date.formatted(.dateTime.day().month(.abbreviated).year()).uppercased())
                .font(.system(size: 10 * scale, weight: .bold, design: .rounded))
                .tracking(1.35 * scale)
                .foregroundStyle(background.secondaryForegroundColor)
        }
    }

    private func metricsPanel(scale: CGFloat) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                metric(
                    value: WorkoutShareFormatters.duration(summary.duration),
                    label: "DURATION",
                    scale: scale
                )
                separator(vertical: true)
                metric(value: "\(summary.exerciseCount)", label: "EXERCISES", scale: scale)
            }
            separator(vertical: false)
            HStack(spacing: 0) {
                metric(value: "\(summary.setCount)", label: "SETS", scale: scale)
                separator(vertical: true)
                metric(
                    value: WorkoutShareFormatters.compactVolume(summary.trainingVolume),
                    label: "VOLUME",
                    scale: scale
                )
            }
        }
        .background(background.panelColor)
        .clipShape(RoundedRectangle(cornerRadius: 16 * scale, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16 * scale, style: .continuous)
                .stroke(background.separatorColor, lineWidth: max(0.6, scale))
        }
    }

    private func metric(value: String, label: String, scale: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 2 * scale) {
            Text(value)
                .font(.system(size: 20 * scale, weight: .heavy, design: .rounded))
                .minimumScaleFactor(0.70)
                .lineLimit(1)
            Text(label)
                .font(.system(size: 7.5 * scale, weight: .bold, design: .rounded))
                .tracking(1.15 * scale)
                .foregroundStyle(background.secondaryForegroundColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14 * scale)
        .frame(height: 54 * scale)
    }

    @ViewBuilder
    private func separator(vertical: Bool) -> some View {
        if vertical {
            Rectangle()
                .fill(background.separatorColor)
                .frame(width: 1)
        } else {
            Rectangle()
                .fill(background.separatorColor)
                .frame(height: 1)
        }
    }

    private func highlightsPanel(scale: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 8 * scale) {
            HStack(alignment: .center) {
                Text("TRAINING HIGHLIGHTS")
                    .font(.system(size: 8 * scale, weight: .black, design: .rounded))
                    .tracking(1.25 * scale)
                Spacer()
                Text("\(summary.repetitionCount) REPS")
                    .font(.system(size: 7.5 * scale, weight: .bold, design: .rounded))
                    .tracking(0.8 * scale)
                    .foregroundStyle(background.secondaryForegroundColor)
            }

            ForEach(summary.exerciseHighlights) { highlight in
                HStack(spacing: 8 * scale) {
                    RoundedRectangle(cornerRadius: 2 * scale)
                        .fill(background.foregroundColor.opacity(0.85))
                        .frame(width: 3 * scale, height: 19 * scale)

                    Text(highlight.name)
                        .font(.system(size: 11.5 * scale, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .layoutPriority(1)

                    Spacer(minLength: 4 * scale)

                    Text(highlight.topSetDescription)
                        .font(.system(size: 10.5 * scale, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.76)
                }
                .frame(height: 22 * scale)
            }

            if summary.exerciseHighlights.isEmpty {
                Text("NO COMPLETED EXERCISES")
                    .font(.system(size: 9 * scale, weight: .bold, design: .rounded))
                    .foregroundStyle(background.secondaryForegroundColor)
            }
        }
        .padding(14 * scale)
        .background(background.panelColor)
        .clipShape(RoundedRectangle(cornerRadius: 14 * scale, style: .continuous))
    }

    private func footer(scale: CGFloat) -> some View {
        HStack {
            Text("TRAIN • TRACK • PROGRESS")
                .font(.system(size: 7.5 * scale, weight: .black, design: .rounded))
                .tracking(1.25 * scale)
            Spacer()
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 12 * scale, weight: .bold))
        }
        .foregroundStyle(background.secondaryForegroundColor)
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
            ]
        ),
        background: .electricBlue
    )
    .frame(width: 360, height: 450)
}
