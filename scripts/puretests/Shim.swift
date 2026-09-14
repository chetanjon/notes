// Stand-ins for the handful of XCTest symbols the pure-logic suites use, so
// that `NotesTests/*.swift` can be compiled and run on the Mac with swiftc
// alone. The real suite runs on a simulator in CI; this is the fast loop.
//
// Only the assertions actually used by the suites are here. Adding an
// assertion to a test means adding it here too, and `scripts/pure-tests.sh`
// will say so by failing to compile rather than by skipping the test.
import Foundation

/// Where a failing assertion puts itself. One run, one collector.
final class PureTestRun {
    static let shared = PureTestRun()
    private(set) var failures: [String] = []
    var currentTest = "<none>"

    func record(_ message: String, _ file: StaticString, _ line: UInt) {
        let name = URL(fileURLWithPath: "\(file)").lastPathComponent
        failures.append("\(currentTest) — \(message)  (\(name):\(line))")
    }

    var failed: Bool { !failures.isEmpty }
    func failuresSince(_ mark: Int) -> [String] { Array(failures[mark...]) }
    var count: Int { failures.count }
}

class XCTestCase {
    required init() {}
}

func XCTFail(_ message: String = "failed",
             file: StaticString = #filePath, line: UInt = #line) {
    PureTestRun.shared.record(message, file, line)
}

func XCTAssertTrue(_ expression: @autoclosure () throws -> Bool,
                   _ message: @autoclosure () -> String = "",
                   file: StaticString = #filePath, line: UInt = #line) rethrows {
    if try !expression() {
        PureTestRun.shared.record(note("expected true", message()), file, line)
    }
}

func XCTAssertFalse(_ expression: @autoclosure () throws -> Bool,
                    _ message: @autoclosure () -> String = "",
                    file: StaticString = #filePath, line: UInt = #line) rethrows {
    if try expression() {
        PureTestRun.shared.record(note("expected false", message()), file, line)
    }
}

func XCTAssertEqual<T: Equatable>(_ a: @autoclosure () throws -> T,
                                  _ b: @autoclosure () throws -> T,
                                  _ message: @autoclosure () -> String = "",
                                  file: StaticString = #filePath, line: UInt = #line) rethrows {
    let left = try a(), right = try b()
    if left != right {
        PureTestRun.shared.record(
            note("\(pretty(left)) != \(pretty(right))", message()), file, line)
    }
}

func XCTAssertEqual<T: FloatingPoint>(_ a: @autoclosure () throws -> T,
                                      _ b: @autoclosure () throws -> T,
                                      accuracy: T,
                                      _ message: @autoclosure () -> String = "",
                                      file: StaticString = #filePath, line: UInt = #line) rethrows {
    let left = try a(), right = try b()
    if !(abs(left - right) <= accuracy) {
        PureTestRun.shared.record(
            note("\(left) is not within \(accuracy) of \(right)", message()), file, line)
    }
}

func XCTAssertNotEqual<T: Equatable>(_ a: @autoclosure () throws -> T,
                                     _ b: @autoclosure () throws -> T,
                                     _ message: @autoclosure () -> String = "",
                                     file: StaticString = #filePath, line: UInt = #line) rethrows {
    if try a() == b() {
        PureTestRun.shared.record(note("expected a difference", message()), file, line)
    }
}

func XCTAssertLessThanOrEqual<T: Comparable>(_ a: @autoclosure () throws -> T,
                                             _ b: @autoclosure () throws -> T,
                                             _ message: @autoclosure () -> String = "",
                                             file: StaticString = #filePath, line: UInt = #line) rethrows {
    let left = try a(), right = try b()
    if !(left <= right) {
        PureTestRun.shared.record(note("\(left) > \(right)", message()), file, line)
    }
}

func XCTAssertNil(_ expression: @autoclosure () throws -> Any?,
                  _ message: @autoclosure () -> String = "",
                  file: StaticString = #filePath, line: UInt = #line) rethrows {
    if let value = try expression() {
        PureTestRun.shared.record(note("expected nil, got \(value)", message()), file, line)
    }
}

func XCTAssertNotNil(_ expression: @autoclosure () throws -> Any?,
                     _ message: @autoclosure () -> String = "",
                     file: StaticString = #filePath, line: UInt = #line) rethrows {
    if try expression() == nil {
        PureTestRun.shared.record(note("expected a value, got nil", message()), file, line)
    }
}

func XCTAssertThrowsError<T>(_ expression: @autoclosure () throws -> T,
                             _ message: @autoclosure () -> String = "",
                             file: StaticString = #filePath, line: UInt = #line,
                             _ errorHandler: (Error) -> Void = { _ in }) {
    do {
        _ = try expression()
        PureTestRun.shared.record(note("expected a throw", message()), file, line)
    } catch {
        errorHandler(error)
    }
}

private func note(_ what: String, _ extra: String) -> String {
    extra.isEmpty ? what : "\(what) — \(extra)"
}

/// Newlines in a diff are the difference, so they have to be visible.
private func pretty(_ value: Any) -> String {
    let text = String(describing: value)
    return text.contains("\n")
        ? "\"\(text.replacingOccurrences(of: "\n", with: "\\n"))\""
        : text
}
