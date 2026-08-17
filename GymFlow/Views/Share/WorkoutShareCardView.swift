import SwiftUI

struct WorkoutShareCardView: View {
    private static let designSize = CGSize(width: 393, height: 852)

    let summary: WorkoutShareSummary
    let background: WorkoutShareBackground

    var body: some View {
        GeometryReader { geometry in
            let scale = min(
                geometry.size.width / Self.designSize.width,
                geometry.size.height / Self.designSize.height
            )

            ZStack {
                WorkoutShareBackgroundView(background: background)

                VStack(alignment: .leading, spacing: 0) {
                    brandHeader(scale: scale)
                    Spacer(minLength: 24 * scale)
                    workoutHeader(scale: scale)
                    Spacer(minLength: 20 * scale)
                    heroPanel(scale: scale)
                    Spacer(minLength: 18 * scale)
                    metricsPanel(scale: scale)
                    Spacer(minLength: 18 * scale)
                    highlightsPanel(scale: scale)

                    if let personalBest = summary.personalBestHighlight {
                        Spacer(minLength: 16 * scale)
                        personalBestPanel(personalBest, scale: scale)
                    }

                    Spacer(minLength: 18 * scale)
                    footer(scale: scale)
                }
                .padding(.horizontal, 28 * scale)
                .padding(.vertical, 30 * scale)
            }
            .foregroundStyle(background.foregroundColor)
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
        }
        .aspectRatio(Self.designSize.width / Self.designSize.height, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(summary.accessibilityDescription)
    }

    private func brandHeader(scale: CGFloat) -> some View {
        HStack(spacing: 8 * scale) {
            Image(systemName: "bolt.heart.fill")
                .font(.system(size: 14 * scale, weight: .bold))
            Text("GYMFLOW")
                .font(.system(size: 12 * scale, weight: .black, design: .rounded))
                .tracking(1.8 * scale)
            Spacer()
            Text("WORKOUT RESULT")
                .font(.system(size: 8.5 * scale, weight: .bold, design: .rounded))
                .tracking(1.15 * scale)
                .foregroundStyle(background.secondaryForegroundColor)
        }
    }

    private func workoutHeader(scale: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 8 * scale) {
            Text(summary.displayWorkoutName.uppercased())
                .font(.system(size: 36 * scale, weight: .black, design: .rounded))
                .tracking(-1.0 * scale)
                .lineLimit(3)
                .minimumScaleFactor(0.64)
                .fixedSize(horizontal: false, vertical: true)

            Text(summary.date.formatted(.dateTime.day().month(.abbreviated).year()).uppercased())
                .font(.system(size: 11 * scale, weight: .bold, design: .rounded))
                .tracking(1.55 * scale)
                .foregroundStyle(background.secondaryForegroundColor)
        }
    }

    private func heroPanel(scale: CGFloat) -> some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 22 * scale, style: .continuous)
                .fill(background.panelColor)

            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 92 * scale, weight: .ultraLight))
                .foregroundStyle(background.foregroundColor.opacity(0.18))
                .offset(x: 212 * scale, y: 8 * scale)

            VStack(alignment: .leading, spacing: 6 * scale) {
                Text("TODAY'S WORKOUT")
                    .font(.system(size: 8.5 * scale, weight: .black, design: .rounded))
                    .tracking(1.4 * scale)
                    .foregroundStyle(background.secondaryForegroundColor)
                Text("WORK EARNED.\nPROGRESS RECORDED.")
                    .font(.system(size: 20 * scale, weight: .black, design: .rounded))
                    .tracking(-0.25 * scale)
                    .lineSpacing(1 * scale)
            }
            .padding(18 * scale)
        }
        .frame(height: 116 * scale)
        .overlay {
            RoundedRectangle(cornerRadius: 22 * scale, style: .continuous)
                .stroke(background.separatorColor, lineWidth: max(0.7, scale))
        }
        .clipped()
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
                metric(value: "\(summary.setCount)", label: "SETS", scale: scale)
            }
            separator(vertical: false)
            HStack(spacing: 0) {
                metric(value: "\(summary.repetitionCount)", label: "REPS", scale: scale)
                separator(vertical: true)
                metric(
                    value: WorkoutShareFormatters.compactVolume(summary.trainingVolume),
                    label: "VOLUME",
                    scale: scale
                )
            }
        }
        .background(background.panelColor)
        .clipShape(RoundedRectangle(cornerRadius: 18 * scale, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18 * scale, style: .continuous)
                .stroke(background.separatorColor, lineWidth: max(0.7, scale))
        }
    }

    private func metric(value: String, label: String, scale: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 3 * scale) {
            Text(value)
                .font(.system(size: 21 * scale, weight: .heavy, design: .rounded))
                .minimumScaleFactor(0.64)
                .lineLimit(1)
            Text(label)
                .font(.system(size: 7.5 * scale, weight: .bold, design: .rounded))
                .tracking(1.2 * scale)
                .foregroundStyle(background.secondaryForegroundColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16 * scale)
        .frame(height: 58 * scale)
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
        VStack(alignment: .leading, spacing: 10 * scale) {
            HStack(alignment: .center) {
                Text("HIGHLIGHTS")
                    .font(.system(size: 8.5 * scale, weight: .black, design: .rounded))
                    .tracking(1.4 * scale)
                Spacer()
                Text("\(summary.exerciseCount) EXERCISES")
                    .font(.system(size: 7.5 * scale, weight: .bold, design: .rounded))
                    .tracking(0.9 * scale)
                    .foregroundStyle(background.secondaryForegroundColor)
            }

            ForEach(summary.exerciseHighlights) { highlight in
                HStack(spacing: 9 * scale) {
                    RoundedRectangle(cornerRadius: 2 * scale)
                        .fill(background.foregroundColor.opacity(0.85))
                        .frame(width: 3 * scale, height: 23 * scale)

                    Text(highlight.name)
                        .font(.system(size: 12 * scale, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .layoutPriority(1)

                    Spacer(minLength: 4 * scale)

                    Text(highlight.topSetDescription)
                        .font(.system(size: 11 * scale, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.70)
                }
                .frame(height: 25 * scale)
            }
        }
        .padding(16 * scale)
        .background(background.panelColor)
        .clipShape(RoundedRectangle(cornerRadius: 18 * scale, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18 * scale, style: .continuous)
                .stroke(background.separatorColor, lineWidth: max(0.7, scale))
        }
    }

    private func personalBestPanel(
        _ personalBest: WorkoutSharePersonalBestHighlight,
        scale: CGFloat
    ) -> some View {
        HStack(spacing: 12 * scale) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 22 * scale, weight: .bold))
                .foregroundStyle(.yellow)
                .frame(width: 34 * scale)

            VStack(alignment: .leading, spacing: 3 * scale) {
                Text("NEW BEST · \(personalBest.typeTitle.uppercased())")
                    .font(.system(size: 7.5 * scale, weight: .black, design: .rounded))
                    .tracking(1.05 * scale)
                    .foregroundStyle(background.secondaryForegroundColor)
                Text(personalBest.exerciseName)
                    .font(.system(size: 12 * scale, weight: .bold, design: .rounded))
                    .lineLimit(1)
                Text(personalBest.setDescription)
                    .font(.system(size: 16 * scale, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                if let metricDescription = personalBest.metricDescription {
                    Text(metricDescription.uppercased())
                        .font(.system(size: 7.5 * scale, weight: .bold, design: .rounded))
                        .tracking(0.55 * scale)
                        .foregroundStyle(background.secondaryForegroundColor)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 4 * scale)
        }
        .padding(.horizontal, 16 * scale)
        .frame(height: 82 * scale)
        .background(background.panelColor)
        .clipShape(RoundedRectangle(cornerRadius: 18 * scale, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18 * scale, style: .continuous)
                .stroke(Color.yellow.opacity(0.5), lineWidth: max(0.8, scale))
        }
    }

    private func footer(scale: CGFloat) -> some View {
        HStack {
            Text("TRAIN • TRACK • PROGRESS")
                .font(.system(size: 8 * scale, weight: .black, design: .rounded))
                .tracking(1.35 * scale)
            Spacer()
            Text("GYMFLOW")
                .font(.system(size: 9 * scale, weight: .black, design: .rounded))
                .tracking(1.2 * scale)
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
