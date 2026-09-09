import XCTest
@testable import Notes

final class DateSpotterTests: XCTestCase {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    /// Monday 7 September 2026, ten in the morning.
    private var now: Date { date(2026, 9, 7, 10, 0) }

    private func find(_ text: String) -> [DateSpotter.Hit] {
        DateSpotter.find(in: text, now: now, calendar: calendar)
    }

    func testSegmentsCutLinesOnSlashesAndSemicolons() {
        XCTAssertEqual(DateSpotter.segments(of: "Plans\n□ Dentist tuesday 3pm / call mum; buy milk\n\n- gym"),
                       ["Plans", "Dentist tuesday 3pm", "call mum", "buy milk", "gym"])
        // A slash inside a date is not a cut.
        XCTAssertEqual(DateSpotter.segments(of: "rent 1/10"), ["rent 1/10"])
    }

    func testTheScreenshotLine() {
        let hits = find("Plans\nDentist tuesday 3pm / call mum at <a time five minutes from now > / buy milk")
        XCTAssertEqual(hits, [DateSpotter.Hit(title: "Dentist", due: date(2026, 9, 8, 15, 0))])
    }

    func testWeekdayAndTime() {
        XCTAssertEqual(find("call the dentist tuesday at 3"), [DateSpotter.Hit(title: "Call the dentist", due: date(2026, 9, 8, 15, 0))])
        XCTAssertEqual(find("Friday 9am gym"), [DateSpotter.Hit(title: "Gym", due: date(2026, 9, 11, 9, 0))])
        XCTAssertEqual(find("thurs 3.30pm review"), [DateSpotter.Hit(title: "Review", due: date(2026, 9, 10, 15, 30))])
        // A weekday alone is due in the morning; today's weekday, past ten, means next week.
        XCTAssertEqual(find("wednesday call mum"), [DateSpotter.Hit(title: "Call mum", due: date(2026, 9, 9, 9, 0))])
        XCTAssertEqual(find("monday call mum"), [DateSpotter.Hit(title: "Call mum", due: date(2026, 9, 14, 9, 0))])
        XCTAssertEqual(find("monday 11am call mum"), [DateSpotter.Hit(title: "Call mum", due: date(2026, 9, 7, 11, 0))])
        XCTAssertEqual(find("next monday call mum").first?.due, date(2026, 9, 14, 9, 0))
    }

    func testTodayTomorrowTonight() {
        XCTAssertEqual(find("call mum tomorrow at 10"), [DateSpotter.Hit(title: "Call mum", due: date(2026, 9, 8, 10, 0))])
        XCTAssertEqual(find("tomorrow morning: bins"), [DateSpotter.Hit(title: "Bins", due: date(2026, 9, 8, 9, 0))])
        XCTAssertEqual(find("tonight pasta"), [DateSpotter.Hit(title: "Pasta", due: date(2026, 9, 7, 20, 0))])
        XCTAssertEqual(find("today 4pm pick up parcel"), [DateSpotter.Hit(title: "Pick up parcel", due: date(2026, 9, 7, 16, 0))])
        XCTAssertEqual(find("this evening water the plants").first?.due, date(2026, 9, 7, 18, 0))
    }

    func testTimeAloneIsTodayOrTomorrow() {
        XCTAssertEqual(find("standup at 11").first?.due, date(2026, 9, 7, 11, 0))
        XCTAssertEqual(find("call at 9am").first?.due, date(2026, 9, 8, 9, 0))
        XCTAssertEqual(find("lunch at noon").first?.due, date(2026, 9, 7, 12, 0))
        XCTAssertEqual(find("15:00 bank").first, DateSpotter.Hit(title: "Bank", due: date(2026, 9, 7, 15, 0)))
    }

    func testInSoMany() {
        XCTAssertEqual(find("call mum in five minutes"), [DateSpotter.Hit(title: "Call mum", due: date(2026, 9, 7, 10, 5))])
        XCTAssertEqual(find("oven in 20 mins").first?.due, date(2026, 9, 7, 10, 20))
        XCTAssertEqual(find("leave in an hour").first?.due, date(2026, 9, 7, 11, 0))
        XCTAssertEqual(find("leave in half an hour").first?.due, date(2026, 9, 7, 10, 30))
    }

    func testDaysOfTheMonth() {
        XCTAssertEqual(find("rent due on the 1st"), [DateSpotter.Hit(title: "Rent due", due: date(2026, 10, 1, 9, 0))])
        XCTAssertEqual(find("the 15th: invoice").first?.due, date(2026, 9, 15, 9, 0))
        XCTAssertEqual(find("flight 3 October 7am"), [DateSpotter.Hit(title: "Flight", due: date(2026, 10, 3, 7, 0))])
        XCTAssertEqual(find("Oct 3rd flight").first?.due, date(2026, 10, 3, 9, 0))
        XCTAssertEqual(find("1st of January party").first?.due, date(2027, 1, 1, 9, 0))
    }

    func testALetterThatGrowsWhenLoweredDoesNotCorruptTheTitle() {
        // "İ" is one unit as written and two lowercased; ranges taken from
        // the lowered string used to be applied to the original.
        let hits = find("İstanbul tomorrow")
        XCTAssertEqual(hits.count, 1)
        XCTAssertEqual(hits.first?.due, date(2026, 9, 8, 9, 0))
        XCTAssertEqual(hits.first?.title, "İstanbul")
    }

    func testTwoThingsAtTheSameTimeAreTwoReminders() {
        // They used to eat each other in the merge.
        let hits = find("gym at 7\ncall mum at 7")
        XCTAssertEqual(hits.count, 2)
        XCTAssertEqual(Set(hits.map(\.title)), ["Gym", "Call mum"])
    }

    func testAPriceIsNotATime() {
        XCTAssertEqual(find("bread 2.20"), [])
        XCTAssertEqual(find("milk 3.50\ncoffee 4.30"), [])
        // With "at" or a meridiem it is a time again.
        XCTAssertEqual(find("standup at 2.20").first?.due, date(2026, 9, 7, 14, 20))
        XCTAssertEqual(find("standup 2.20pm").first?.due, date(2026, 9, 7, 14, 20))
    }

    func testADayTheMonthDoesNotHaveRollsToOneItDoes() {
        // September has 30 days, so "the 31st" is 31 October, not 1 October.
        XCTAssertEqual(find("rent on the 31st").first?.due, date(2026, 10, 31, 9, 0))
        XCTAssertEqual(find("sept 31 party"), [])
    }

    func testAnIntervalKeepsTheTimeGivenWithIt() {
        XCTAssertEqual(find("call the bank in 3 days at 9").first?.due, date(2026, 9, 10, 9, 0))
    }

    func testABareHourCountsNextToADay() {
        // A bare hour reads the same here as after "at": under seven is an
        // afternoon one, seven and over a morning one.
        let hit = find("gym friday 8").first
        XCTAssertEqual(hit?.due, date(2026, 9, 11, 8, 0))
        XCTAssertEqual(find("gym friday 5").first?.due, date(2026, 9, 11, 17, 0))
        XCTAssertEqual(hit?.title, "Gym")
        // With no day, a bare number is just a number.
        XCTAssertEqual(find("buy 8 eggs"), [])
    }

    func testSeveralDatesOnOneLineReadLeftToRight() {
        // The weekday is written first, so it is the day.
        XCTAssertEqual(find("dentist tuesday, rent on the 1st").first?.due, date(2026, 10, 1, 9, 0))
    }

    func testNothingDatedGivesNothing() {
        XCTAssertEqual(find("Shop\nmilk eggs bread\nsat in the sun\nmorning pages"), [])
        XCTAssertEqual(find("budget $3,000 for 2 weeks"), [])
    }

    func testTitleFallsBackToTheLine() {
        XCTAssertEqual(find("tomorrow").first?.title, "Tomorrow")
    }
}
