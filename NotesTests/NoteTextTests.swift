import XCTest
@testable import Notes

final class NoteTextTests: XCTestCase {
    func testTitleIsFirstNonEmptyLine() {
        XCTAssertEqual(NoteText.title("Walking app\nVoice notes"), "Walking app")
        XCTAssertEqual(NoteText.title("\n\n  Second  \nThird"), "Second")
        XCTAssertEqual(NoteText.title("□ milk"), "milk")
        XCTAssertEqual(NoteText.title(""), "New note")
        XCTAssertEqual(NoteText.title("  \n□ "), "New note")
    }

    func testPlainPreviewJoinsBodyLines() {
        XCTAssertEqual(NoteText.preview("Title\nVoice notes\n\non walks"), "Voice notes on walks")
        XCTAssertEqual(NoteText.preview("Title"), "")
    }

    func testChecklistSummary() {
        let text = "Groceries\n■ eggs\n□ milk\n□ rice\n■ bread"
        XCTAssertTrue(NoteText.isChecklist(text))
        XCTAssertEqual(NoteText.checklistSummary(text), NoteText.Summary(done: 2, total: 4, open: ["milk", "rice"]))
        XCTAssertEqual(NoteText.preview(text), "2/4 done · milk, rice")
        XCTAssertEqual(NoteText.widgetPreview(text), "2/4 · milk, rice")
    }

    func testAllDone() {
        let text = "Groceries\n■ eggs\n■ milk"
        XCTAssertEqual(NoteText.preview(text), "All done")
        XCTAssertEqual(NoteText.widgetPreview(text), "All done")
    }

    func testWidgetPreviewIsFirstBodyLine() {
        XCTAssertEqual(NoteText.widgetPreview("Title\n\nfirst\nsecond"), "first")
        XCTAssertEqual(NoteText.widgetPreview("Title"), "")
    }

    func testWantsSummaryForLongPlainNotes() {
        XCTAssertTrue(NoteText.wantsSummary("Title\nfirst\n\nsecond"))
        XCTAssertTrue(NoteText.wantsSummary("Title\n" + String(repeating: "a", count: 61)))
        XCTAssertFalse(NoteText.wantsSummary("Title\nshort"))
        XCTAssertFalse(NoteText.wantsSummary("Title"))
        XCTAssertFalse(NoteText.wantsSummary("Groceries\n□ milk\n□ eggs"))
    }

    func testCountersMatchLabelThenNumber() {
        let text = "Day\nWater 3\nPushups  20\n□ Water 3\nRoom 4b\n3\nCall 555 1234\nSteps 1234567"
        XCTAssertEqual(NoteText.counters(text), [
            NoteText.Counter(label: "Water", value: 3, lineIndex: 1),
            NoteText.Counter(label: "Pushups", value: 20, lineIndex: 2),
        ])
        // The title line is never a counter.
        XCTAssertEqual(NoteText.counters("Water 3"), [])
    }

    func testCheckedItemIsNeverACounter() {
        XCTAssertEqual(NoteText.counters("Gym\n□ Water 3\nPushups 20"),
                       [NoteText.Counter(label: "Pushups", value: 20, lineIndex: 2)])
    }

    func testSteppingKeepsWhitespaceAndFloorsAtZero() {
        XCTAssertEqual(NoteText.stepping(counterAt: 1, by: 1, in: "Day\nWater 3"), "Day\nWater 4")
        XCTAssertEqual(NoteText.stepping(counterAt: 1, by: 1, in: "Day\n  Pushups\t20  "), "Day\n  Pushups\t21  ")
        XCTAssertEqual(NoteText.stepping(counterAt: 1, by: -5, in: "Day\nWater 3"), "Day\nWater 0")
        XCTAssertNil(NoteText.stepping(counterAt: 1, by: 1, in: "Day\n□ Water 3"))
        XCTAssertNil(NoteText.stepping(counterAt: 0, by: 1, in: "Water 3"))
    }

    func testPinnedCountersKeepNoteOrderAndStopAtTheLimit() {
        let text = "Gym\nPushups 20\n□ stretch\nSquats 10\nnotes here\nWater 3\nSteps 900"
        XCTAssertEqual(NoteText.pinnedCounters(text), [
            PinnedCounter(label: "Pushups", value: 20, line: 1),
            PinnedCounter(label: "Squats", value: 10, line: 3),
            PinnedCounter(label: "Water", value: 3, line: 5),
        ])
        XCTAssertEqual(NoteText.pinnedCounters(text, limit: 1),
                       [PinnedCounter(label: "Pushups", value: 20, line: 1)])
        XCTAssertEqual(NoteText.pinnedCounters("Groceries\n□ eggs\n■ milk"), [])
    }

    func testBlankNotes() {
        XCTAssertTrue(NoteText.isBlank(""))
        XCTAssertTrue(NoteText.isBlank(" \n\n  "))
        XCTAssertTrue(NoteText.isBlank("□ \n■ "))
        XCTAssertFalse(NoteText.isBlank("a"))
        XCTAssertFalse(NoteText.isBlank("\n□ milk"))
    }

    func testOneLineCollapsesAndCuts() {
        XCTAssertEqual(NoteText.oneLine("Groceries\n□ milk\n\n■  eggs \nand   bread", limit: 100),
                       "Groceries milk eggs and bread")
        XCTAssertEqual(NoteText.oneLine("Title\nabcdefghij", limit: 8), "Title ab…")
        XCTAssertEqual(NoteText.oneLine("", limit: 8), "")
    }

    func testSearchIsCaseInsensitiveOverTitleAndBody() {
        let text = "Walking app\nVoice notes on walks"
        XCTAssertTrue(NoteText.matches(text, query: "WALK"))
        XCTAssertTrue(NoteText.matches(text, query: "voice"))
        XCTAssertFalse(NoteText.matches(text, query: "running"))
        XCTAssertTrue(NoteText.matches(text, query: "   "))
    }

    func testSpokenFormReadsOpenItemsOrFirstLines() {
        XCTAssertEqual(NoteText.spoken("Groceries\n□ milk\n■ eggs\n□ bread\n□ tea"),
                       "3 left on Groceries: milk, bread, and tea.")
        XCTAssertEqual(NoteText.spoken("Groceries\n□ milk\n□ eggs"), "2 left on Groceries: milk and eggs.")
        XCTAssertEqual(NoteText.spoken("Groceries\n□ milk\n■ eggs"), "One thing left on Groceries: milk.")
        XCTAssertEqual(NoteText.spoken("Groceries\n■ milk"), "Everything on Groceries is done.")
        XCTAssertEqual(NoteText.spoken("Ideas\nA walking app\n\n  Voice notes  "), "Ideas: A walking app. Voice notes")
        XCTAssertEqual(NoteText.spoken("Ideas"), "Ideas has nothing under the title.")
    }
}

extension NoteTextTests {
    func testCapitalisedStartsTheLineAndThePronoun() {
        XCTAssertEqual(NoteText.capitalised("call the dentist"), "Call the dentist")
        XCTAssertEqual(NoteText.capitalised("i received the parcel, i think it's fine"), "I received the parcel, I think it's fine")
        XCTAssertEqual(NoteText.capitalised("□ milk and i"), "□ Milk and I")
        // A brand spelt with a small first letter is capitalised too; a known cost.
        XCTAssertEqual(NoteText.capitalised("iPhone is fine"), "IPhone is fine")
        XCTAssertEqual(NoteText.capitalised(""), "")
        XCTAssertEqual(NoteText.capitalised("  3 things"), "  3 things")
    }
}

extension NoteTextTests {
    func testTidiedIsTheCarefulTypist() {
        XCTAssertEqual(NoteText.tidied("i recieved the parcel , its fine"), "I recieved the parcel, its fine")
        XCTAssertEqual(NoteText.tidied("  milk,eggs ,bread .  "), "Milk, eggs, bread.")
        XCTAssertEqual(NoteText.tidied("call  the   dentist"), "Call the dentist")
        // Numbers keep their commas; a clean line is unchanged.
        XCTAssertEqual(NoteText.tidied("Budget $3,000"), "Budget $3,000")
        XCTAssertEqual(NoteText.tidied("Call the dentist Tuesday, it's at 3."), "Call the dentist Tuesday, it's at 3.")
        XCTAssertEqual(NoteText.tidied(""), "")
    }
}

extension NoteTextTests {
    func testAppendingJoinsAfterABlankLineAndDropsThePlaceholder() {
        XCTAssertEqual(NoteText.appending("New note\nStanding more might help my back", to: "Standing desk\nknee hurt for a week\n"),
                       "Standing desk\nknee hurt for a week\n\nStanding more might help my back")
        XCTAssertEqual(NoteText.appending("Thoughts\n\nmore\n", to: "Desk"), "Desk\n\nThoughts\n\nmore")
        XCTAssertEqual(NoteText.appending("New note\n", to: "Desk"), "Desk")
        XCTAssertEqual(NoteText.appending("Words", to: ""), "Words")
    }
}
