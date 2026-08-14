import SwiftUI

struct WorkoutCalendarView: View {
    let sessions: [WorkoutSession]

    @State private var displayedMonth = WorkoutHistoryGrouper.startOfMonth(containing: Date())
    @State private var selection: CalendarDaySelection?

    private var calendar: Calendar {
        var value = Calendar.current
        value.firstWeekday = 2
        return value
    }

    var body: some View {
        let groupedSessions = WorkoutHistoryGrouper.groupCompletedSessions(
            sessions,
            calendar: calendar
        )
        let summary = WorkoutHistoryGrouper.summary(
            inMonthContaining: displayedMonth,
            sessions: sessions,
            calendar: calendar
        )

        ScrollView {
            VStack(spacing: 18) {
                monthHeader
                weekdayHeader
                monthGrid(groupedSessions: groupedSessions)
                MonthSummaryView(summary: summary)
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .accessibilityIdentifier("workout-calendar")
        .sheet(item: $selection) { value in
            NavigationStack {
                CalendarDayDetailView(day: value.day, sessions: value.sessions)
            }
        }
    }

    private var monthHeader: some View {
        VStack(spacing: 8) {
            HStack {
                Button("Previous Month", systemImage: "chevron.left") {
                    moveMonth(by: -1)
                }
                .labelStyle(.iconOnly)
                .frame(minWidth: 44, minHeight: 44)

                Spacer()
                Text(displayedMonth, format: .dateTime.month(.wide).year())
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                Spacer()

                Button("Next Month", systemImage: "chevron.right") {
                    moveMonth(by: 1)
                }
                .labelStyle(.iconOnly)
                .frame(minWidth: 44, minHeight: 44)
            }

            if !calendar.isDate(displayedMonth, equalTo: Date(), toGranularity: .month) {
                Button("Return to Current Month") {
                    displayedMonth = WorkoutHistoryGrouper.startOfMonth(
                        containing: Date(),
                        calendar: calendar
                    )
                }
                .font(.subheadline)
            }
        }
    }

    private var weekdayHeader: some View {
        LazyVGrid(columns: gridColumns, spacing: 8) {
            ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .accessibilityHidden(true)
            }
        }
    }

    private func monthGrid(groupedSessions: [Date: [WorkoutSession]]) -> some View {
        LazyVGrid(columns: gridColumns, spacing: 8) {
            ForEach(Array(monthDates.enumerated()), id: \.offset) { _, date in
                if let date {
                    let day = calendar.startOfDay(for: date)
                    let daySessions = groupedSessions[day] ?? []
                    CalendarDayCell(
                        date: date,
                        workoutCount: daySessions.count,
                        isToday: calendar.isDateInToday(date),
                        isSelected: selection?.day == day
                    ) {
                        selection = CalendarDaySelection(day: day, sessions: daySessions)
                    }
                } else {
                    Color.clear
                        .frame(minHeight: 48)
                        .accessibilityHidden(true)
                }
            }
        }
    }

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    }

    private var monthDates: [Date?] {
        WorkoutHistoryGrouper.monthGridDates(containing: displayedMonth, calendar: calendar)
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let startingIndex = max(0, min(symbols.count - 1, calendar.firstWeekday - 1))
        return Array(symbols[startingIndex...] + symbols[..<startingIndex])
    }

    private func moveMonth(by value: Int) {
        guard let date = calendar.date(byAdding: .month, value: value, to: displayedMonth) else { return }
        displayedMonth = WorkoutHistoryGrouper.startOfMonth(containing: date, calendar: calendar)
    }
}

private struct CalendarDayCell: View {
    let date: Date
    let workoutCount: Int
    let isToday: Bool
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Text(date, format: .dateTime.day())
                    .font(.body.weight(isToday || isSelected ? .semibold : .regular))
                    .frame(width: 32, height: 30)
                    .background {
                        if isToday {
                            Circle().stroke(Color.accentColor, lineWidth: 1.5)
                        }
                        if isSelected {
                            Circle().fill(Color.accentColor.opacity(0.14))
                        }
                    }

                HStack(spacing: 2) {
                    ForEach(0..<min(workoutCount, 2), id: \.self) { _ in
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 5, height: 5)
                    }
                    if workoutCount > 2 {
                        Text("+")
                            .font(.caption2.bold())
                            .foregroundStyle(.tint)
                    }
                }
                .frame(height: 7)
            }
            .frame(maxWidth: .infinity, minHeight: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var accessibilityLabel: String {
        let dateText = date.formatted(.dateTime.month(.wide).day().year())
        switch workoutCount {
        case 0: return "\(dateText), no workouts"
        case 1: return "\(dateText), 1 workout"
        default: return "\(dateText), \(workoutCount) workouts"
        }
    }

    private var accessibilityIdentifier: String {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return "calendar-day-\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
    }
}

private struct MonthSummaryView: View {
    let summary: WorkoutMonthSummary

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            summaryItem(title: "Workouts", value: "\(summary.workoutCount)")
            Divider()
            summaryItem(title: "Training Days", value: "\(summary.trainingDayCount)")
            Divider()
            summaryItem(title: "Total Time", value: GymFlowFormatters.duration(summary.totalDuration))
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .combine)
    }

    private func summaryItem(title: String, value: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.headline)
                .minimumScaleFactor(0.8)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct CalendarDaySelection: Identifiable {
    let day: Date
    let sessions: [WorkoutSession]

    var id: Date { day }
}

#Preview { GymFlowPreview { WorkoutCalendarView(sessions: []) } }
