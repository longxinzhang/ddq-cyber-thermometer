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

    func testFormatsNetworkRates() {
        XCTAssertEqual(512.0.bytesPerSecondText, "0 KB/s")
        XCTAssertEqual(1_536.0.bytesPerSecondText, "1.5 KB/s")
        XCTAssertEqual(42_000.0.bytesPerSecondText, "41 KB/s")
        XCTAssertEqual(1_572_864.0.bytesPerSecondText, "1.5 MB/s")

        XCTAssertEqual(512.0.compactBytesPerSecondText, "0KB")
        XCTAssertEqual(1_536.0.compactBytesPerSecondText, "1.5KB")
        XCTAssertEqual(42_000.0.compactBytesPerSecondText, "41KB")
        XCTAssertEqual(1_572_864.0.compactBytesPerSecondText, "1.5MB")
    }
}
