import XCTest
@testable import Notes

final class BriefTests: XCTestCase {
    func testLineLeavesEmptyPartsOut() {
        let brief = Brief(decided: ["October", "$3,000 budget"], open: ["pick a hotel"], next: "compare the two near the station")
        XCTAssertEqual(brief.line, "Decided: October, $3,000 budget. Open: pick a hotel. Next: compare the two near the station.")
        XCTAssertEqual(Brief(decided: [], open: ["pick a hotel."], next: " ").line, "Open: pick a hotel.")
        XCTAssertTrue(Brief(decided: [], open: [], next: "").isEmpty)
    }

    func testKeptDropsInventions() {
        let text = "Japan trip\nOctober, budget $3,000\nhotel still open\ncompare the two near the station"
        let brief = Brief.kept(decided: ["October", "Flights booked"], open: ["hotel"], next: "compare the two near the station", from: text)
        XCTAssertEqual(brief, Brief(decided: ["October"], open: ["hotel"], next: "compare the two near the station"))
        XCTAssertNil(Brief.kept(decided: ["Flights booked"], open: [], next: "book flights", from: text))
    }

    func testWantedNeedsThreePlainBodyLines() {
        XCTAssertTrue(Brief.wanted(for: "Trip\na\nb\nc"))
        XCTAssertFalse(Brief.wanted(for: "Trip\na\n\nb"))
        XCTAssertFalse(Brief.wanted(for: "Shop\n□ a\n□ b\n□ c"))
    }

    func testRecallCandidatesNeedWordsAndOverlap() {
        let desk = NoteFinder.Card(id: UUID(), text: "Standing desk\nstanding all day hurt my knee for a week, back to sitting")
        let shop = NoteFinder.Card(id: UUID(), text: "Shop\nmilk eggs bread")
        let writing = "Thinking about getting a standing desk for the study, standing more during the day might help my back"
        XCTAssertEqual(Recall.candidates(for: writing, among: [shop, desk]).map(\.id), [desk.id])
        XCTAssertEqual(Recall.candidates(for: "standing desk", among: [shop, desk]), [])
    }
}
