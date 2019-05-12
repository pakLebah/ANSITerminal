import XCTest
@testable import ANSITerminal

final class ANSITerminalTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(ANSITerminal().text, "Hello, World!")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
