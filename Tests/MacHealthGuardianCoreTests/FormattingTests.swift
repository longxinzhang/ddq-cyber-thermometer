import XCTest
@testable import MacHealthGuardianCore

final class FormattingTests: XCTestCase {
    func testFormatsPercentText() {
        XCTAssertEqual(42.4.percentText, "42%")
        XCTAssertEqual(42.5.shortPercentText, "43%")
    }

    func testFormatsGigabytes() {
        XCTAssertEqual(8.25.gbText, "8.2 GB")
        XCTAssertEqual(128.0.gbText, "128 GB")
    }
}
