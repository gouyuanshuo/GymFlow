import SwiftUI

// The share card is built from these sections, stacked top to bottom by `WorkoutShareCardView`.
// Each one is a real `View` rather than a `some View`-returning helper so SwiftUI can identify and
// diff them individually, and so each can be previewed and adjusted without reading the whole card.
// All of them read their scale and palette from `\.workoutShareCardStyle`.

/// The "GYMFLOW · WORKOUT RESULT" strip along the top of the card.
struct ShareCardBrandHeader: View {
    @Environment(\.workoutShareCardStyle) private var style

    var body: some View {
        HStack(spacing: style.length(8)) {
            Image(systemName: "bolt.heart.fill")
                .font(.system(size: style.length(14), weight: .bold))
            Text("GYMFLOW")
                .font(style.font(12, .black))
                .tracking(style.tracking(1.8))
            Spacer()
            Text("WORKOUT RESULT")
                .font(style.font(8.5, .bold))
                .tracking(style.tracking(1.15))
                .foregroundStyle(style.secondaryForegroundColor)
        }
    }
}

/// The workout's name and date, set as the card's headline.
struct ShareCardWorkoutHeader: View {
    @Environment(\.workoutShareCardStyle) private var style
    let workoutName: String
    let date: Date

    var body: some View {
        VStack(alignment: .leading, spacing: style.length(8)) {
            Text(workoutName.uppercased())
                .font(style.font(36, .black))
                .tracking(style.tracking(-1.0))
                .lineLimit(3)
                .minimumScaleFactor(0.64)
                .fixedSize(horizontal: false, vertical: true)

            Text(date.formatted(.dateTime.day().month(.abbreviated).year()).uppercased())
                .font(style.font(11, .bold))
                .tracking(style.tracking(1.55))
                .foregroundStyle(style.secondaryForegroundColor)
        }
    }
}

/// The decorative banner beneath the headline.
struct ShareCardHeroPanel: View {
    @Environment(\.workoutShareCardStyle) private var style

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Color.clear

            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: style.length(92), weight: .ultraLight))
                .foregroundStyle(style.foregroundColor.opacity(0.18))
                .offset(x: style.length(212), y: style.length(8))

            VStack(alignment: .leading, spacing: style.length(6)) {
                Text("TODAY'S WORKOUT")
                    .font(style.font(8.5, .black))
                    .tracking(style.tracking(1.4))
                    .foregroundStyle(style.secondaryForegroundColor)
                Text("WORK EARNED.\nPROGRESS RECORDED.")
                    .font(style.font(20, .black))
                    .tracking(style.tracking(-0.25))
                    .lineSpacing(style.length(1))
            }
            .padding(style.length(18))
        }
        .frame(height: style.length(116))
        .workoutSharePanel(style, cornerRadius: 22)
    }
}

/// The four headline totals, arranged in a two-by-two grid.
struct ShareCardMetricsPanel: View {
    @Environment(\.workoutShareCardStyle) private var style
    let summary: WorkoutShareSummary

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ShareCardMetric(
                    value: WorkoutShareFormatters.duration(summary.duration),
                    label: "DURATION"
                )
                ShareCardDivider(axis: .vertical)
                ShareCardMetric(value: "\(summary.setCount)", label: "SETS")
            }
            ShareCardDivider(axis: .horizontal)
            HStack(spacing: 0) {
                ShareCardMetric(value: "\(summary.repetitionCount)", label: "REPS")
                ShareCardDivider(axis: .vertical)
                ShareCardMetric(
                    value: WorkoutShareFormatters.compactVolume(summary.trainingVolume),
                    label: "VOLUME"
                )
            }
        }
        .workoutSharePanel(style, cornerRadius: 18)
    }
}

/// One cell of ``ShareCardMetricsPanel``: a large value above a small caption.
struct ShareCardMetric: View {
    @Environment(\.workoutShareCardStyle) private var style
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: style.length(3)) {
            Text(value)
                .font(style.font(21, .heavy))
                .minimumScaleFactor(0.64)
                .lineLimit(1)
            Text(label)
                .font(style.font(7.5, .bold))
                .tracking(style.tracking(1.2))
                .foregroundStyle(style.secondaryForegroundColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, style.length(16))
        .frame(height: style.length(58))
    }
}

/// A one-pixel rule between metric cells.
struct ShareCardDivider: View {
    @Environment(\.workoutShareCardStyle) private var style
    let axis: Axis

    var body: some View {
        Rectangle()
            .fill(style.separatorColor)
            .frame(
                width: axis == .vertical ? 1 : nil,
                height: axis == .horizontal ? 1 : nil
            )
    }
}

/// The per-exercise top sets listed under a "HIGHLIGHTS" heading.
struct ShareCardHighlightsPanel: View {
    @Environment(\.workoutShareCardStyle) private var style
    let exerciseCount: Int
    let highlights: [WorkoutShareExerciseHighlight]

    var body: some View {
        VStack(alignment: .leading, spacing: style.length(10)) {
            HStack {
                Text("HIGHLIGHTS")
                    .font(style.font(8.5, .black))
                    .tracking(style.tracking(1.4))
                Spacer()
                Text("\(exerciseCount) EXERCISES")
                    .font(style.font(7.5, .bold))
                    .tracking(style.tracking(0.9))
                    .foregroundStyle(style.secondaryForegroundColor)
            }

            ForEach(highlights) { highlight in
                ShareCardHighlightRow(highlight: highlight)
            }
        }
        .padding(style.length(16))
        .workoutSharePanel(style, cornerRadius: 18)
    }
}

/// One exercise inside ``ShareCardHighlightsPanel``: its name and its best set.
struct ShareCardHighlightRow: View {
    @Environment(\.workoutShareCardStyle) private var style
    let highlight: WorkoutShareExerciseHighlight

    var body: some View {
        HStack(spacing: style.length(9)) {
            RoundedRectangle(cornerRadius: style.length(2))
                .fill(style.foregroundColor.opacity(0.85))
                .frame(width: style.length(3), height: style.length(23))

            Text(highlight.name)
                .font(style.font(12, .semibold))
                .lineLimit(1)
                .truncationMode(.tail)
                // The name yields space to the set description only after truncating.
                .layoutPriority(1)

            Spacer(minLength: style.length(4))

            Text(highlight.topSetDescription)
                .font(style.font(11, .bold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.70)
        }
        .frame(height: style.length(25))
    }
}

/// The gold-edged banner shown when the workout set a new personal best.
struct ShareCardPersonalBestPanel: View {
    @Environment(\.workoutShareCardStyle) private var style
    let personalBest: WorkoutSharePersonalBestHighlight

    var body: some View {
        HStack(spacing: style.length(12)) {
            Image(systemName: "trophy.fill")
                .font(.system(size: style.length(22), weight: .bold))
                .foregroundStyle(.yellow)
                .frame(width: style.length(34))

            VStack(alignment: .leading, spacing: style.length(3)) {
                Text("NEW BEST · \(personalBest.typeTitle.uppercased())")
                    .font(style.font(7.5, .black))
                    .tracking(style.tracking(1.05))
                    .foregroundStyle(style.secondaryForegroundColor)
                Text(personalBest.exerciseName)
                    .font(style.font(12, .bold))
                    .lineLimit(1)
                Text(personalBest.setDescription)
                    .font(style.font(16, .black))
                    .monospacedDigit()
                    .lineLimit(1)
                if let metricDescription = personalBest.metricDescription {
                    Text(metricDescription.uppercased())
                        .font(style.font(7.5, .bold))
                        .tracking(style.tracking(0.55))
                        .foregroundStyle(style.secondaryForegroundColor)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: style.length(4))
        }
        .padding(.horizontal, style.length(16))
        .frame(height: style.length(82))
        .workoutSharePanel(
            style,
            cornerRadius: 18,
            edgeColor: .yellow.opacity(0.5),
            edgeWidth: max(0.8, style.scale)
        )
    }
}

/// The tagline and wordmark closing the card.
struct ShareCardFooter: View {
    @Environment(\.workoutShareCardStyle) private var style

    var body: some View {
        HStack {
            Text("TRAIN • TRACK • PROGRESS")
                .font(style.font(8, .black))
                .tracking(style.tracking(1.35))
            Spacer()
            Text("GYMFLOW")
                .font(style.font(9, .black))
                .tracking(style.tracking(1.2))
        }
        .foregroundStyle(style.secondaryForegroundColor)
    }
}
