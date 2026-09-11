import XCTest
@testable import Notes

final class VocabularyTests: XCTestCase {
    func testItTakesNamesFromTheMiddleOfALine() {
        XCTAssertEqual(Vocabulary.terms(in: ["Call Priya about the Fitzwilliam lease"]),
                       ["Priya", "Fitzwilliam"])
    }

    func testAWordThatOnlyStartsALineIsNotAName() {
        // Every line starts with a capital. Treating those as names would
        // fill the list with "Milk" and leave no room for "Priya".
        XCTAssertEqual(Vocabulary.terms(in: ["Milk\nEggs\nBread"]), [])
    }

    func testAWordAfterAFullStopIsNotAName() {
        XCTAssertEqual(Vocabulary.terms(in: ["We flew to Lisbon. Lisbon was hot."]), ["Lisbon"])
    }

    func testAChecklistMarkerIsNotPartOfTheFirstWord() {
        XCTAssertEqual(Vocabulary.terms(in: ["□ Ring Aoife", "■ Email Dara"]), ["Aoife", "Dara"])
    }

    func testPunctuationAroundAWordIsNotPartOfIt() {
        XCTAssertEqual(Vocabulary.terms(in: ["Ask about (Ravensbourne), then go"]), ["Ravensbourne"])
    }

    func testTheMostUsedNamesComeFirstAndTheListIsCapped() {
        let notes = ["see Ada and Bo", "see Ada", "see Ada", "see Bo", "see Cy"]
        XCTAssertEqual(Vocabulary.terms(in: notes, limit: 2), ["Ada", "Bo"])
    }

    func testANameIsOnlyThereOnce() {
        XCTAssertEqual(Vocabulary.terms(in: ["meet Priya", "ring Priya", "text Priya"]), ["Priya"])
    }

    func testSingleLettersAndNumbersAreNotNames() {
        XCTAssertEqual(Vocabulary.terms(in: ["flat B at 4 Oakfield"]), ["Oakfield"])
    }
}
