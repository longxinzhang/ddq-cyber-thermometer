import Foundation
import XCTest
@testable import MacHealthGuardian

final class MonthCalendarGridTests: XCTestCase {
    private var calendar: Calendar!

    override func setUp() {
        super.setUp()
        calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "zh_CN")
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 1
    }

    func testUsesMondayFirstLayout() {
        let grid = MonthCalendarGrid.grid(
            monthContaining: date(year: 2026, month: 7, day: 16),
            today: date(year: 2026, month: 7, day: 16),
            calendar: calendar
        )

        XCTAssertEqual(grid.title, "2026年7月")
        XCTAssertNil(grid.days[0])
        XCTAssertNil(grid.days[1])
        XCTAssertEqual(grid.days[2]?.day, 1)
        XCTAssertEqual(grid.days[17], MonthCalendarDay(day: 16, isToday: true))
    }

    func testMovesBetweenMonths() {
        let july = MonthCalendarGrid.monthStart(
            containing: date(year: 2026, month: 7, day: 16),
            calendar: calendar
        )

        let june = MonthCalendarGrid.grid(
            monthContaining: MonthCalendarGrid.month(offsetBy: -1, from: july, calendar: calendar),
            calendar: calendar
        )
        let august = MonthCalendarGrid.grid(
            monthContaining: MonthCalendarGrid.month(offsetBy: 1, from: july, calendar: calendar),
            calendar: calendar
        )

        XCTAssertEqual(june.title, "2026年6月")
        XCTAssertEqual(august.title, "2026年8月")
    }

    private func date(year: Int, month: Int, day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }
}
