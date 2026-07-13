// minimal dependency free test runner. works under the command line tools toolchain
// where XCTest and the swift-testing macro plugin are unavailable. each test suite is a
// free function that takes a TestRunner and records expectations; main.swift calls them
// and exits non-zero if any expectation failed.

final class TestRunner {
    private(set) var passed = 0
    private(set) var failed = 0

    func expect(
        _ condition: Bool,
        _ message: @autoclosure () -> String = "expectation failed",
        file: StaticString = #fileID,
        line: UInt = #line
    ) {
        if condition {
            passed += 1
        } else {
            failed += 1
            print("FAIL \(file):\(line) - \(message())")
        }
    }

    func expectEqual<T: Equatable>(
        _ actual: T,
        _ expected: T,
        file: StaticString = #fileID,
        line: UInt = #line
    ) {
        expect(actual == expected, "expected \(expected) but got \(actual)", file: file, line: line)
    }

    // returns a process exit code: 0 when everything passed, 1 otherwise.
    func summarize() -> Int32 {
        print("tests: \(passed) passed, \(failed) failed")
        return failed == 0 ? 0 : 1
    }
}
