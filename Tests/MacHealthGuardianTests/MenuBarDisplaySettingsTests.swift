import Foundation
import XCTest
@testable import MacHealthGuardian

final class MenuBarDisplaySettingsTests: XCTestCase {
    private var defaults: UserDefaults!
    private var defaultsSuiteName: String!

    override func setUp() {
        super.setUp()
        defaultsSuiteName = "MenuBarDisplaySettingsTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: defaultsSuiteName)!
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: defaultsSuiteName)
        defaults = nil
        defaultsSuiteName = nil
        super.tearDown()
    }

    func testDefaultsToAllMetrics() {
        let settings = MenuBarDisplaySettings(defaults: defaults)

        XCTAssertEqual(settings.metrics, [.memoryPressure, .memoryUsage, .cpuUsage])
    }

    func testPersistsMetricsInStableOrder() {
        let settings = MenuBarDisplaySettings(defaults: defaults)

        settings.metrics = [.cpuUsage, .memoryPressure]

        XCTAssertEqual(settings.metrics, [.memoryPressure, .cpuUsage])
    }

    func testKeepsLastMetricEnabled() {
        let settings = MenuBarDisplaySettings(defaults: defaults)
        settings.metrics = [.memoryPressure]

        settings.setEnabled(false, for: .memoryPressure)

        XCTAssertEqual(settings.metrics, [.memoryPressure])
        XCTAssertFalse(settings.canDisable(.memoryPressure))
    }

    func testIgnoresUnknownStoredValues() {
        defaults.set(["unknown"], forKey: "menuBarDisplayMetrics")
        let settings = MenuBarDisplaySettings(defaults: defaults)

        XCTAssertEqual(settings.metrics, [.memoryPressure, .memoryUsage, .cpuUsage])
    }
}
