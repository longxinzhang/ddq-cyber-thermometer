import Foundation
import XCTest
@testable import MacHealthGuardian

final class QuickLinkSettingsTests: XCTestCase {
    private var defaults: UserDefaults!
    private var defaultsSuiteName: String!

    override func setUp() {
        super.setUp()
        defaultsSuiteName = "QuickLinkSettingsTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: defaultsSuiteName)!
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: defaultsSuiteName)
        defaults = nil
        defaultsSuiteName = nil
        super.tearDown()
    }

    func testDefaultFirstLinkIsStatsPage() {
        let settings = QuickLinkSettings(defaults: defaults)

        XCTAssertEqual(settings.links.count, 3)
        XCTAssertEqual(settings.links[0]?.title, "雪鸡号池用量")
        XCTAssertEqual(settings.links[0]?.urlString, "https://ddq.stats.trytrythisai.com/")
        XCTAssertNil(settings.links[1])
        XCTAssertNil(settings.links[2])
    }

    func testPersistsThreeSlots() {
        let settings = QuickLinkSettings(defaults: defaults)
        settings.setLink(QuickLink(title: "控制台", urlString: "https://example.com/"), at: 1)

        let reloaded = QuickLinkSettings(defaults: defaults)

        XCTAssertEqual(reloaded.links[1]?.title, "控制台")
        XCTAssertEqual(reloaded.links[1]?.urlString, "https://example.com/")
    }

    func testNormalizesUrlSchemeWhenMissing() {
        let link = QuickLink(title: "例子", rawURLString: "example.com/path")

        XCTAssertEqual(link?.urlString, "https://example.com/path")
    }

    func testRejectsInvalidLinks() {
        XCTAssertNil(QuickLink(title: "", rawURLString: "https://example.com/"))
        XCTAssertNil(QuickLink(title: "例子", rawURLString: "ftp://example.com/"))
        XCTAssertNil(QuickLink(title: "例子", rawURLString: "not a url"))
    }
}
