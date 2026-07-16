import Foundation

struct MonthCalendarDay: Equatable {
    let day: Int
    let isToday: Bool
}

struct MonthCalendarGrid: Equatable {
    static let weekdayTitles = ["一", "二", "三", "四", "五", "六", "日"]

    let title: String
    let monthStart: Date
    let days: [MonthCalendarDay?]

    static func grid(
        monthContaining date: Date,
        today: Date = Date(),
        calendar: Calendar = .mondayFirstGregorian
    ) -> MonthCalendarGrid {
        let monthStart = Self.monthStart(containing: date, calendar: calendar)
        let dayRange = calendar.range(of: .day, in: .month, for: monthStart) ?? 1..<1
        let leadingBlankCount = (calendar.component(.weekday, from: monthStart) - calendar.firstWeekday + 7) % 7

        var days: [MonthCalendarDay?] = Array(repeating: nil, count: leadingBlankCount)

        for day in dayRange {
            guard let dayDate = calendar.date(byAdding: .day, value: day - 1, to: monthStart) else {
                continue
            }

            days.append(
                MonthCalendarDay(
                    day: day,
                    isToday: calendar.isDate(dayDate, inSameDayAs: today)
                )
            )
        }

        while days.count < 42 {
            days.append(nil)
        }

        return MonthCalendarGrid(
            title: monthTitle(for: monthStart, calendar: calendar),
            monthStart: monthStart,
            days: Array(days.prefix(42))
        )
    }

    static func monthStart(
        containing date: Date,
        calendar: Calendar = .mondayFirstGregorian
    ) -> Date {
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? date
    }

    static func month(
        offsetBy monthOffset: Int,
        from monthStart: Date,
        calendar: Calendar = .mondayFirstGregorian
    ) -> Date {
        calendar.date(byAdding: .month, value: monthOffset, to: monthStart) ?? monthStart
    }

    private static func monthTitle(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month], from: date)
        let year = components.year ?? 0
        let month = components.month ?? 0
        return "\(year)年\(month)月"
    }
}

extension Calendar {
    static var mondayFirstGregorian: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "zh_CN")
        calendar.timeZone = .current
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 1
        return calendar
    }
}
