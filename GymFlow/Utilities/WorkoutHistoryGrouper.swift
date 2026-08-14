import Foundation

struct WorkoutMonthSummary: Equatable {
    let workoutCount: Int
    let trainingDayCount: Int
    let totalDuration: TimeInterval
    let totalVolume: Double

    static let empty = WorkoutMonthSummary(
        workoutCount: 0,
        trainingDayCount: 0,
        totalDuration: 0,
        totalVolume: 0
    )
}

enum WorkoutHistoryGrouper {
    static func groupCompletedSessions(
        _ sessions: [WorkoutSession],
        calendar: Calendar = .current
    ) -> [Date: [WorkoutSession]] {
        var grouped: [Date: [WorkoutSession]] = [:]
        for session in sessions where session.status == .completed {
            let day = calendar.startOfDay(for: session.startedAt)
            grouped[day, default: []].append(session)
        }
        for day in grouped.keys {
            grouped[day]?.sort { $0.startedAt < $1.startedAt }
        }
        return grouped
    }

    static func completedSessions(
        inMonthContaining date: Date,
        from sessions: [WorkoutSession],
        calendar: Calendar = .current
    ) -> [WorkoutSession] {
        guard let interval = calendar.dateInterval(of: .month, for: date) else { return [] }
        return sessions
            .filter {
                $0.status == .completed
                    && $0.startedAt >= interval.start
                    && $0.startedAt < interval.end
            }
            .sorted { $0.startedAt < $1.startedAt }
    }

    static func summary(
        inMonthContaining date: Date,
        sessions: [WorkoutSession],
        calendar: Calendar = .current
    ) -> WorkoutMonthSummary {
        let monthlySessions = completedSessions(
            inMonthContaining: date,
            from: sessions,
            calendar: calendar
        )
        guard !monthlySessions.isEmpty else { return .empty }
        let trainingDays = Set(monthlySessions.map { calendar.startOfDay(for: $0.startedAt) })
        let totalDuration = monthlySessions.reduce(0) { total, session in
            guard let completedAt = session.completedAt else { return total }
            return total + max(0, completedAt.timeIntervalSince(session.startedAt))
        }
        return WorkoutMonthSummary(
            workoutCount: monthlySessions.count,
            trainingDayCount: trainingDays.count,
            totalDuration: totalDuration,
            totalVolume: monthlySessions.reduce(0) { $0 + $1.trainingVolume }
        )
    }

    static func startOfMonth(
        containing date: Date,
        calendar: Calendar = .current
    ) -> Date {
        calendar.dateInterval(of: .month, for: date)?.start ?? calendar.startOfDay(for: date)
    }

    static func monthGridDates(
        containing date: Date,
        calendar: Calendar = .current
    ) -> [Date?] {
        let monthStart = startOfMonth(containing: date, calendar: calendar)
        guard let days = calendar.range(of: .day, in: .month, for: monthStart) else { return [] }
        let weekday = calendar.component(.weekday, from: monthStart)
        let leadingEmptyDays = (weekday - calendar.firstWeekday + 7) % 7
        var dates = Array<Date?>(repeating: nil, count: leadingEmptyDays)
        dates.append(contentsOf: days.compactMap { day in
            calendar.date(byAdding: .day, value: day - 1, to: monthStart)
        })
        while dates.count % 7 != 0 {
            dates.append(nil)
        }
        return dates
    }
}
