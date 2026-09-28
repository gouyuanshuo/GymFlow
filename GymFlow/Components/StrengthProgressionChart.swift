import Charts
import SwiftUI

/// Data point representing a single historical performance in an exercise.
struct StrengthDataPoint: Identifiable, Equatable {
    let id: UUID
    let date: Date
    let weight: Double
    let repetitions: Int
    let estimated1RM: Double
    let totalVolume: Double
    let sessionName: String

    init(
        id: UUID = UUID(),
        date: Date,
        weight: Double,
        repetitions: Int,
        totalVolume: Double = 0,
        sessionName: String = ""
    ) {
        self.id = id
        self.date = date
        self.weight = weight
        self.repetitions = repetitions
        self.totalVolume = totalVolume
        self.sessionName = sessionName
        // Epley Formula for 1RM: weight * (1 + reps / 30)
        self.estimated1RM = (weight > 0 && repetitions > 0 && repetitions <= 30)
            ? weight * (1.0 + Double(repetitions) / 30.0)
            : weight
    }
}

/// Interactive strength progression chart powered by Apple's native Charts framework.
struct StrengthProgressionChart: View {
    let dataPoints: [StrengthDataPoint]
    @State private var selectedPoint: StrengthDataPoint?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            chartHeader

            if dataPoints.isEmpty {
                ContentUnavailableView(
                    "No Progress Data",
                    systemImage: "chart.xyaxis.line",
                    description: Text("Complete workouts with this exercise to see your strength curve.")
                )
                .frame(height: 200)
            } else {
                interactiveChart
                statMetricsRow
            }
        }
        .gymGlassCard()
    }

    // MARK: - Subviews

    private var chartHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("STRENGTH PROGRESSION")
                    .font(.caption.weight(.bold))
                    .tracking(1)
                    .foregroundStyle(.secondary)

                if let selected = selectedPoint {
                    HStack(spacing: 8) {
                        Text("\(GymFlowFormatters.weight(selected.estimated1RM)) kg e1RM")
                            .font(.title3.bold().monospacedDigit())
                            .foregroundStyle(GymTheme.volt)

                        Text("(\(GymFlowFormatters.weight(selected.weight)) kg × \(selected.repetitions))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else if let latest = dataPoints.last {
                    HStack(spacing: 8) {
                        Text("\(GymFlowFormatters.weight(latest.estimated1RM)) kg e1RM")
                            .font(.title3.bold().monospacedDigit())
                            .foregroundStyle(GymTheme.volt)

                        Text("Latest")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(GymTheme.volt.opacity(0.15))
                            .foregroundStyle(GymTheme.volt)
                            .clipShape(Capsule())
                    }
                }
            }

            Spacer()

            if selectedPoint != nil {
                Button("Reset") {
                    withAnimation(.snappy) { selectedPoint = nil }
                }
                .font(.caption.weight(.medium))
                .buttonStyle(.bordered)
            }
        }
    }

    private var interactiveChart: some View {
        Chart {
            ForEach(dataPoints) { point in
                // Shaded Area under the progression curve
                AreaMark(
                    x: .value("Date", point.date),
                    y: .value("Estimated 1RM", point.estimated1RM)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [GymTheme.volt.opacity(0.35), GymTheme.volt.opacity(0.0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)

                // Main Strength Line
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Estimated 1RM", point.estimated1RM)
                )
                .foregroundStyle(GymTheme.volt)
                .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                .interpolationMethod(.catmullRom)

                // Data Points
                PointMark(
                    x: .value("Date", point.date),
                    y: .value("Estimated 1RM", point.estimated1RM)
                )
                .foregroundStyle(GymTheme.volt)
                .symbolSize(point.id == selectedPoint?.id ? 80 : 36)
            }

            // Interactive Scrubber Indicator
            if let selected = selectedPoint {
                RuleMark(x: .value("Selected Date", selected.date))
                    .foregroundStyle(Color.primary.opacity(0.3))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                    .annotation(position: .top, spacing: 6) {
                        Text(selected.date, format: .dateTime.month(.abbreviated).day())
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                    }
            }
        }
        .chartYScale(domain: yAxisDomain)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
                    .foregroundStyle(Color.primary.opacity(0.1))
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color.primary.opacity(0.08))
                AxisValueLabel {
                    if let val = value.as(Double.self) {
                        Text("\(Int(val)) kg")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                guard let plotFrame = proxy.plotFrame else { return }
                                let xPosition = value.location.x - geometry[plotFrame].origin.x
                                if let date: Date = proxy.value(atX: xPosition) {
                                    findClosestPoint(to: date)
                                }
                            }
                    )
            }
        }
        .frame(height: 180)
    }

    private var statMetricsRow: some View {
        HStack(spacing: 12) {
            statTile(
                title: "BEST WEIGHT",
                value: "\(GymFlowFormatters.weight(dataPoints.map(\.weight).max() ?? 0)) kg",
                icon: "scalemass.fill",
                color: GymTheme.cyan
            )

            statTile(
                title: "MAX e1RM",
                value: "\(GymFlowFormatters.weight(dataPoints.map(\.estimated1RM).max() ?? 0)) kg",
                icon: "trophy.fill",
                color: GymTheme.gold
            )

            statTile(
                title: "SESSIONS",
                value: "\(dataPoints.count)",
                icon: "calendar",
                color: GymTheme.volt
            )
        }
    }

    private func statTile(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: icon)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(color)

            Text(value)
                .font(.subheadline.weight(.bold).monospacedDigit())
                .foregroundStyle(.primary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .tertiarySystemFill))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Helpers

    private var yAxisDomain: ClosedRange<Double> {
        let maxVal = dataPoints.map(\.estimated1RM).max() ?? 100
        let minVal = dataPoints.map(\.estimated1RM).min() ?? 0
        let lower = max(0, minVal - 10)
        let upper = maxVal + 10
        return lower...upper
    }

    private func findClosestPoint(to date: Date) {
        guard !dataPoints.isEmpty else { return }
        let closest = dataPoints.min {
            abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
        }
        if let closest, closest != selectedPoint {
            UISelectionFeedbackGenerator().selectionChanged()
            selectedPoint = closest
        }
    }
}
