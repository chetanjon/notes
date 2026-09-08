import XCTest
@testable import Notes

final class NoteFinderTests: XCTestCase {
    func testRankPutsTheNotesSharingMostWordsFirst() {
        let a = NoteFinder.Card(id: UUID(), text: "Groceries\nmilk eggs bread")
        let b = NoteFinder.Card(id: UUID(), text: "This week\ncall the dentist tuesday")
        let c = NoteFinder.Card(id: UUID(), text: "Dentist\nnew dentist on high street, tuesday hours")
        let ranked = NoteFinder.rank([a, b, c], for: "when is the dentist tuesday")
        XCTAssertEqual(ranked.map(\.id), [b.id, c.id, a.id])
    }

    func testRankKeepsTheGivenOrderOnTies() {
        let a = NoteFinder.Card(id: UUID(), text: "one")
        let b = NoteFinder.Card(id: UUID(), text: "two")
        XCTAssertEqual(NoteFinder.rank([a, b], for: "nothing here").map(\.id), [a.id, b.id])
    }
}

extension NoteFinderTests {
    func testOverlapCountsTheQuestionsWordsInTheCard() {
        let card = NoteFinder.Card(id: UUID(), text: "Shop\nmilk eggs call the dentist tuesday")
        XCTAssertEqual(NoteFinder.overlap(card, with: "when is the dentist"), 1)
        XCTAssertEqual(NoteFinder.overlap(card, with: "wifi password"), 0)
    }
}
