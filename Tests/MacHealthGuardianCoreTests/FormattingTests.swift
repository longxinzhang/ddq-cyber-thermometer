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

        XCTAssertEqual(100.0.compactBytesPerSecondText, "0.10KB")
        XCTAssertEqual(512.0.compactBytesPerSecondText, "0.51KB")
        XCTAssertEqual(1_536.0.compactBytesPerSecondText, "1.53KB")
        XCTAssertEqual(10_240.0.compactBytesPerSecondText, "10.2KB")
        XCTAssertEqual(42_000.0.compactBytesPerSecondText, "42.0KB")
        XCTAssertEqual(999_000.0.compactBytesPerSecondText, "0.99MB")
        XCTAssertEqual(120_000_000.0.compactBytesPerSecondText, "0.12GB")
    }
}
