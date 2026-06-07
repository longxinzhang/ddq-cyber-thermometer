import XCTest
@testable import MacHealthGuardianCore

final class ReleaseVersionTests: XCTestCase {
    func testComparesNumericVersions() {
        XCTAssertLessThan(ReleaseVersion("0.4.0"), ReleaseVersion("0.4.1"))
        XCTAssertGreaterThan(ReleaseVersion("v1.10.0"), ReleaseVersion("v1.9.9"))
    }

    func testTreatsMissingComponentsAsZero() {
        XCTAssertEqual(ReleaseVersion("1.2"), ReleaseVersion("1.2.0"))
        XCTAssertLessThan(ReleaseVersion("1.2.0"), ReleaseVersion("1.2.1"))
    }
}
