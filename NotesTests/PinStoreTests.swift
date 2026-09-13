import XCTest
@testable import Notes

final class PinStoreTests: XCTestCase {
    func testNoteURLCarriesTheID() {
        let id = UUID()
        let url = URL(string: "notes://note/\(id.uuidString)")!
        XCTAssertEqual(PinStore.noteID(from: url), id)
        XCTAssertNil(PinStore.noteID(from: URL(string: "notes://note/nope")!))
        XCTAssertNil(PinStore.noteID(from: URL(string: "https://example.com/note/\(id.uuidString)")!))
        XCTAssertNil(PinStore.noteID(from: PinStore.newNoteURL))
    }

    func testNewNoteURL() {
        XCTAssertTrue(PinStore.isNewNote(PinStore.newNoteURL))
        XCTAssertFalse(PinStore.isNewNote(URL(string: "notes://note/\(UUID().uuidString)")!))
        XCTAssertFalse(PinStore.isNewNote(URL(string: "https://example.com/new")!))
    }
}

extension PinStoreTests {
    /// The records the widget reads are written by one version and read by
    /// the next. Swift's own decoder throws on a missing key rather than
    /// using a property's default, so these are the tests that catch a
    /// field added later blanking the Lock Screen.
    func testAPinnedRecordFromAnEarlierVersionStillDecodes() throws {
        let id = UUID()
        let json = """
        {"id":"\(id.uuidString)","title":"Shop","preview":"milk","updatedAt":0}
        """
        let pinned = try JSONDecoder().decode(PinStore.Pinned.self, from: Data(json.utf8))
        XCTAssertEqual(pinned.id, id)
        XCTAssertEqual(pinned.title, "Shop")
        XCTAssertEqual(pinned.counters, [])
        XCTAssertFalse(pinned.isChecklist)
        XCTAssertEqual(pinned.total, 0)
    }

    func testACounterFromAnEarlierVersionStillDecodes() throws {
        let counter = try JSONDecoder().decode(PinnedCounter.self, from: Data("{\"label\":\"Water\"}".utf8))
        XCTAssertEqual(counter.label, "Water")
        XCTAssertEqual(counter.value, 0)
        XCTAssertEqual(counter.line, 0)
    }

    func testARecentSummaryFromAnEarlierVersionStillDecodes() throws {
        let id = UUID()
        let json = """
        [{"id":"\(id.uuidString)","title":"Shop","preview":"milk","updatedAt":0}]
        """
        let notes = try JSONDecoder().decode([RecentStore.Summary].self, from: Data(json.utf8))
        XCTAssertEqual(notes.count, 1)
        XCTAssertEqual(notes.first?.title, "Shop")
        XCTAssertEqual(notes.first?.isPinned, false)
    }

    func testARecordWithoutAnIdIsRefused() {
        XCTAssertThrowsError(try JSONDecoder().decode(PinStore.Pinned.self, from: Data("{\"title\":\"Shop\"}".utf8)))
    }
}

extension PinStoreTests {
    func testTheDictateURLIsRecognised() {
        XCTAssertTrue(PinStore.isDictate(PinStore.dictateURL))
    }

    func testTheThreeLinkShapesAreNotMistakenForEachOther() {
        // They all arrive at the same place in the app and do very
        // different things there.
        XCTAssertFalse(PinStore.isDictate(PinStore.newNoteURL))
        XCTAssertFalse(PinStore.isNewNote(PinStore.dictateURL))
        XCTAssertNil(PinStore.noteID(from: PinStore.dictateURL))
    }
}
