import XCTest
@testable import MacHealthGuardianCore

final class SwapUsageParserTests: XCTestCase {
    func testParsesMegabytes() throws {
        let output = "vm.swapusage: total = 8192.00M  used = 512.00M  free = 7680.00M  (encrypted)"
        let usedGB = try XCTUnwrap(SwapUsageParser.usedGB(from: output))

        XCTAssertEqual(usedGB, 0.5, accuracy: 0.001)
    }

    func testParsesGigabytes() throws {
        let output = "vm.swapusage: total = 8.00G  used = 1.50G  free = 6.50G  (encrypted)"
        let usedGB = try XCTUnwrap(SwapUsageParser.usedGB(from: output))

        XCTAssertEqual(usedGB, 1.5, accuracy: 0.001)
    }

    func testParsesKilobytes() throws {
        let output = "vm.swapusage: total = 8388608K  used = 1048576K  free = 7340032K"
        let usedGB = try XCTUnwrap(SwapUsageParser.usedGB(from: output))

        XCTAssertEqual(usedGB, 1, accuracy: 0.001)
    }

    func testReturnsNilForMissingUsedValue() {
        XCTAssertNil(SwapUsageParser.usedGB(from: "vm.swapusage: unavailable"))
    }
}
