import XCTest
@testable import Notes

final class ReminderStampTests: XCTestCase {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    func testDateAndTime() {
        XCTAssertEqual(ReminderStamp.parse("2026-09-15T15:00", calendar: calendar), date(2026, 9, 15, 15, 0))
        XCTAssertEqual(ReminderStamp.parse(" 2026-09-15T08:30 ", calendar: calendar), date(2026, 9, 15, 8, 30))
    }

    func testDateAloneIsDueInTheMorning() {
        XCTAssertEqual(ReminderStamp.parse("2026-09-15", calendar: calendar), date(2026, 9, 15, 9, 0))
    }

    func testAnythingElseIsNil() {
        XCTAssertNil(ReminderStamp.parse("", calendar: calendar))
        XCTAssertNil(ReminderStamp.parse("tuesday", calendar: calendar))
        XCTAssertNil(ReminderStamp.parse("2026-13-01", calendar: calendar))
        XCTAssertNil(ReminderStamp.parse("2026-09-15T25:00", calendar: calendar))
        XCTAssertNil(ReminderStamp.parse("2026-09", calendar: calendar))
    }

    func testTodayNamesTheWeekdayAndTheDate() {
        let tuesday = date(2026, 9, 8, 12, 0)
        XCTAssertEqual(ReminderStamp.today(tuesday, calendar: calendar, locale: Locale(identifier: "en_US")),
                       "Tuesday, 2026-09-08")
    }
}

extension ReminderStampTests {
    func testWeekListsSevenDaysFromToday() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let tuesday = calendar.date(from: DateComponents(year: 2026, month: 9, day: 8, hour: 12))!
        let week = ReminderStamp.week(from: tuesday, calendar: calendar, locale: Locale(identifier: "en_US"))
        let lines = week.split(separator: "\n").map(String.init)
        XCTAssertEqual(lines.count, 7)
        XCTAssertEqual(lines[0], "Tuesday 2026-09-08 (today)")
        XCTAssertEqual(lines[1], "Wednesday 2026-09-09 (tomorrow)")
        XCTAssertEqual(lines[6], "Monday 2026-09-14")
    }
}
