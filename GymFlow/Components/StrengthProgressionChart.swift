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

    init?(
        id: UUID = UUID(),
        date: Date,
        weight: Double,
        repetitions: Int,
        totalVolume: Double = 0,
        sessionName: String = ""
    ) {
        guard let estimatedOneRepMax = ExercisePerformanceService.estimatedOneRepMax(
            weight: weight,
            repetitions: repetitions
        ) else { return nil }
        self.id = id
        self.date = date
        self.weight = weight
        self.repetitions = repetitions
        self.totalVolume = totalVolume
        self.sessionName = sessionName
        self.estimated1RM = estimatedOneRepMax
    }
}

/// Interactive strength progression chart powered by Apple's native Charts framework.
struct StrengthProgressionChart: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let dataPoints: [StrengthDataPoint]
    let bestWeight: Double
    @State private var selectedPoint: StrengthDataPoint?
    @State private var rawSelectedDate: Date?

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
        .onChange(of: dataPoints) { _, points in
            if let selectedPoint {
                self.selectedPoint = points.first { $0.id == selectedPoint.id }
            }
        }
    }

    // MARK: - Subviews

    private var rowLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(spacing: 8))
    }

    private var chartHeader: some View {
        rowLayout {
            VStack(alignment: .leading, spacing: 2) {
                Text("STRENGTH PROGRESSION")
                    .font(.caption.weight(.bold))
                    .tracking(1)
                    .foregroundStyle(.secondary)

                if let selected = selectedPoint {
                    rowLayout {
                        Text("\(GymFlowFormatters.weight(selected.estimated1RM)) kg e1RM")
                            .font(.title3.bold().monospacedDigit())
                            .foregroundStyle(GymTheme.voltForeground)

                        Text("(\(GymFlowFormatters.weight(selected.weight)) kg × \(selected.repetitions))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else if let latest = dataPoints.last {
                    rowLayout {
                        Text("\(GymFlowFormatters.weight(latest.estimated1RM)) kg e1RM")
                            .font(.title3.bold().monospacedDigit())
                            .foregroundStyle(GymTheme.voltForeground)

                        Text("Latest")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(GymTheme.volt.opacity(0.15))
                            .foregroundStyle(GymTheme.voltForeground)
                            .clipShape(Capsule())
                    }
                }
            }

            if !dynamicTypeSize.isAccessibilitySize { Spacer() }

            if selectedPoint != nil {
                Button("Reset") {
                    withAnimation(.snappy) {
                        selectedPoint = nil
                        rawSelectedDate = nil
                    }
                }
                .font(.caption.weight(.medium))
                .buttonStyle(.bordered)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
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
                .foregroundStyle(GymTheme.voltForeground)
                .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                .interpolationMethod(.catmullRom)

                // Data Points
                PointMark(
                    x: .value("Date", point.date),
                    y: .value("Estimated 1RM", point.estimated1RM)
                )
                .foregroundStyle(GymTheme.voltForeground)
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
        .chartXSelection(value: $rawSelectedDate)
        // A tap selects a point without installing a drag recognizer over the parent scroll view.
        .chartGesture { proxy in
            SpatialTapGesture()
                .onEnded { event in
                    proxy.selectXValue(at: event.location.x)
                }
        }
        .onChange(of: rawSelectedDate) { _, date in
            if let date { findClosestPoint(to: date) }
        }
        .frame(height: 180)
        .accessibilityIdentifier("strength-progression-chart")
    }

    private var statMetricsRow: some View {
        rowLayout {
            statTile(
                title: "BEST WEIGHT",
                value: "\(GymFlowFormatters.weight(bestWeight)) kg",
                icon: "scalemass.fill",
                color: GymTheme.cyanForeground
            )

            statTile(
                title: "MAX e1RM",
                value: "\(GymFlowFormatters.weight(dataPoints.map(\.estimated1RM).max() ?? 0)) kg",
                icon: "trophy.fill",
                color: GymTheme.goldForeground
            )

            statTile(
                title: "SESSIONS",
                value: "\(dataPoints.count)",
                icon: "calendar",
                color: GymTheme.voltForeground
            )
        }
    }

    private func statTile(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: icon)
                .font(.caption2.weight(.bold))
                .foregroundStyle(color)

            Text(value)
                .font(.subheadline.weight(.bold).monospacedDigit())
                .foregroundStyle(.primary)
        }
        .fixedSize(horizontal: false, vertical: true)
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
