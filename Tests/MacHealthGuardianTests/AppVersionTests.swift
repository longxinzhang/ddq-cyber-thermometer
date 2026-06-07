import XCTest
@testable import MacHealthGuardian

final class AppVersionTests: XCTestCase {
    func testUsesShortVersionWhenAvailable() {
        let title = AppVersion.displayText(infoDictionary: [
            "CFBundleShortVersionString": "1.2.3",
            "CFBundleVersion": "9"
        ])

        XCTAssertEqual(title, "版本 1.2.3")
    }

    func testFallsBackToBuildVersion() {
        let title = AppVersion.displayText(infoDictionary: [
            "CFBundleVersion": "9"
        ])

        XCTAssertEqual(title, "版本 9")
    }

    func testFallsBackToPlaceholder() {
        XCTAssertEqual(AppVersion.displayText(infoDictionary: nil), "版本 --")
    }
}
