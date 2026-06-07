import XCTest
@testable import MacHealthGuardianCore

final class MemoryPressureCalculatorTests: XCTestCase {
    func testReportsNormalPressureWhenMemoryIsAvailable() {
        let pressure = MemoryPressureCalculator.calculate(
            totalGB: 16,
            availableGB: 8,
            compressedGB: 0.2,
            wiredGB: 2,
            swapUsedGB: 0,
            swapOutsPerSecond: 0
        )

        XCTAssertEqual(pressure.level, .normal)
        XCTAssertLessThan(pressure.score, 55)
    }

    func testReportsWarningWhenAvailableMemoryIsLow() {
        let pressure = MemoryPressureCalculator.calculate(
            totalGB: 16,
            availableGB: 1.2,
            compressedGB: 0,
            wiredGB: 2,
            swapUsedGB: 0,
            swapOutsPerSecond: 0
        )

        XCTAssertEqual(pressure.level, .warning)
        XCTAssertGreaterThanOrEqual(pressure.score, 55)
        XCTAssertLessThan(pressure.score, 80)
    }

    func testReportsCriticalForCombinedCompressionWiredMemoryAndSwap() {
        let pressure = MemoryPressureCalculator.calculate(
            totalGB: 16,
            availableGB: 0.5,
            compressedGB: 3,
            wiredGB: 9,
            swapUsedGB: 3,
            swapOutsPerSecond: 600
        )

        XCTAssertEqual(pressure.level, .critical)
        XCTAssertEqual(pressure.score, 100)
    }

    func testSwapOutRateRaisesPressureMoreThanStaleSwapUsageAlone() {
        let staleSwap = MemoryPressureCalculator.calculate(
            totalGB: 16,
            availableGB: 4,
            compressedGB: 0.5,
            wiredGB: 3,
            swapUsedGB: 3,
            swapOutsPerSecond: 0
        )
        let activeSwapOut = MemoryPressureCalculator.calculate(
            totalGB: 16,
            availableGB: 4,
            compressedGB: 0.5,
            wiredGB: 3,
            swapUsedGB: 3,
            swapOutsPerSecond: 600
        )

        XCTAssertGreaterThan(activeSwapOut.score, staleSwap.score)
    }
}
