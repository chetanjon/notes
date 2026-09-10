import XCTest
@testable import Notes

final class NotifyPlanTests: XCTestCase {
    func testIdentifierIsStablePerNoteAndLine() {
        let id = UUID()
        let due = Date(timeIntervalSince1970: 1_800_000_000)
        XCTAssertEqual(NotifyPlan.identifier(noteID: id, body: "Dentist", due: due),
                       NotifyPlan.identifier(noteID: id, body: " dentist ", due: due))
        XCTAssertNotEqual(NotifyPlan.identifier(noteID: id, body: "Dentist", due: due),
                          NotifyPlan.identifier(noteID: id, body: "Rent", due: due))
        XCTAssertNotEqual(NotifyPlan.identifier(noteID: id, body: "Dentist", due: due),
                          NotifyPlan.identifier(noteID: UUID(), body: "Dentist", due: due))
        // Two lines that read the same at different times keep one each.
        XCTAssertNotEqual(NotifyPlan.identifier(noteID: id, body: "Standup", due: due),
                          NotifyPlan.identifier(noteID: id, body: "Standup", due: due.addingTimeInterval(86_400)))
    }

    func testFingerprintIsDeterministic() {
        XCTAssertEqual(NotifyPlan.fingerprint(""), "cbf29ce484222325")
        XCTAssertNotEqual(NotifyPlan.fingerprint("a"), NotifyPlan.fingerprint("b"))
    }

    func testStaleAreTheLinesNoLongerInTheNote() {
        let text = "Plans\ndentist tuesday 3pm\nrent due on the 1st"
        XCTAssertEqual(NotifyPlan.stale(["Dentist", "Rent due", "Call mum"], in: text), ["Call mum"])
    }
}
