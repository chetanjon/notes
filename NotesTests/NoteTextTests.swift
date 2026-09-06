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

    func testStackListsOpenItemsAndCountsTheRest() {
        let text = "Groceries\n■ eggs\n□ milk\n□ rice\n□ bread\n□ tea\n□ salt"
        let stack = NoteText.stack(text, limit: 4)
        XCTAssertEqual(stack.rows, [.item(text: "milk", line: 2), .item(text: "rice", line: 3),
                                    .item(text: "bread", line: 4), .item(text: "tea", line: 5)])
        XCTAssertEqual(stack.more, 1)
        XCTAssertTrue(stack.isChecklist)
        XCTAssertFalse(stack.hasCounters)
        XCTAssertEqual(stack.done, 1)
        XCTAssertEqual(stack.total, 6)
    }

    func testStackOfAPlainNoteIsItsBodyLines() {
        let stack = NoteText.stack("Title\n\nfirst\n  second  \nthird", limit: 2)
        XCTAssertEqual(stack.rows, [.text("first"), .text("second")])
        XCTAssertEqual(stack.more, 1)
        XCTAssertFalse(stack.isChecklist)
        XCTAssertEqual(stack.total, 0)
    }

    func testTogglingAnItemByLineNumber() {
        let text = "Groceries\n□ milk\n■ eggs\nplain"
        XCTAssertEqual(NoteText.togglingItem(at: 1, in: text), "Groceries\n■ milk\n■ eggs\nplain")
        XCTAssertEqual(NoteText.togglingItem(at: 2, in: text), "Groceries\n□ milk\n□ eggs\nplain")
        XCTAssertNil(NoteText.togglingItem(at: 3, in: text))
        XCTAssertNil(NoteText.togglingItem(at: 9, in: text))
    }

    func testStackOfAFinishedChecklistIsEmpty() {
        let stack = NoteText.stack("Groceries\n■ eggs\n■ milk")
        XCTAssertEqual(stack.rows, [])
        XCTAssertEqual(stack.more, 0)
        XCTAssertEqual(stack.done, 2)
        XCTAssertEqual(stack.total, 2)
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

    func testCheckedItemBeatsCounter() {
        let stack = NoteText.stack("Gym\n□ Water 3\nPushups 20")
        XCTAssertEqual(stack.rows, [.item(text: "Water 3", line: 1), .counter(label: "Pushups", value: 20, line: 2)])
        XCTAssertTrue(stack.isChecklist)
        XCTAssertTrue(stack.hasCounters)
    }

    func testSteppingKeepsWhitespaceAndFloorsAtZero() {
        XCTAssertEqual(NoteText.stepping(counterAt: 1, by: 1, in: "Day\nWater 3"), "Day\nWater 4")
        XCTAssertEqual(NoteText.stepping(counterAt: 1, by: 1, in: "Day\n  Pushups\t20  "), "Day\n  Pushups\t21  ")
        XCTAssertEqual(NoteText.stepping(counterAt: 1, by: -5, in: "Day\nWater 3"), "Day\nWater 0")
        XCTAssertNil(NoteText.stepping(counterAt: 1, by: 1, in: "Day\n□ Water 3"))
        XCTAssertNil(NoteText.stepping(counterAt: 0, by: 1, in: "Water 3"))
    }

    func testStackMixesItemsAndCountersInNoteOrder() {
        let stack = NoteText.stack("Gym\nPushups 20\n□ stretch\n■ warm up\nSquats 10\nnotes here")
        XCTAssertEqual(stack.rows, [
            .counter(label: "Pushups", value: 20, line: 1),
            .item(text: "stretch", line: 2),
            .counter(label: "Squats", value: 10, line: 4),
        ])
        XCTAssertEqual(stack.done, 1)
        XCTAssertEqual(stack.total, 2)
    }

    func testBlankNotes() {
        XCTAssertTrue(NoteText.isBlank(""))
        XCTAssertTrue(NoteText.isBlank(" \n\n  "))
        XCTAssertTrue(NoteText.isBlank("□ \n■ "))
        XCTAssertFalse(NoteText.isBlank("a"))
        XCTAssertFalse(NoteText.isBlank("\n□ milk"))
    }

    func testSearchIsCaseInsensitiveOverTitleAndBody() {
        let text = "Walking app\nVoice notes on walks"
        XCTAssertTrue(NoteText.matches(text, query: "WALK"))
        XCTAssertTrue(NoteText.matches(text, query: "voice"))
        XCTAssertFalse(NoteText.matches(text, query: "running"))
        XCTAssertTrue(NoteText.matches(text, query: "   "))
    }
}
