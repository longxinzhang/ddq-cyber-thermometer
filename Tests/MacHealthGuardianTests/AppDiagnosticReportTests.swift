import Foundation
import XCTest
@testable import MacHealthGuardianCore
@testable import MacHealthGuardian

final class AppDiagnosticReportTests: XCTestCase {
    func testBuildsCopyableDiagnosticReport() {
        let report = AppDiagnosticReport.text(
            snapshot: snapshot(),
            appVersionTitle: "版本 1.2.3",
            operatingSystem: "Version 15.5 (Build 24F74)",
            architecture: "arm64"
        )

        XCTAssertTrue(report.contains("动动枪赛博体温计诊断信息"))
        XCTAssertTrue(report.contains("版本 1.2.3"))
        XCTAssertTrue(report.contains("系统: Version 15.5 (Build 24F74)"))
        XCTAssertTrue(report.contains("架构: arm64"))
        XCTAssertTrue(report.contains("内存压力: 偏高 62%"))
        XCTAssertTrue(report.contains("内存占用: 70% (11.2 GB / 16.0 GB)"))
        XCTAssertTrue(report.contains("可用内存: 4.8 GB"))
        XCTAssertTrue(report.contains("活跃内存: 6.2 GB"))
        XCTAssertTrue(report.contains("固定内存: 3.1 GB"))
        XCTAssertTrue(report.contains("压缩内存: 1.4 GB"))
        XCTAssertTrue(report.contains("交换空间: 0.7 GB"))
        XCTAssertTrue(report.contains("Swap Out 速率: 125 pages/s"))
        XCTAssertTrue(report.contains("CPU 占用: 23%"))
        XCTAssertTrue(report.contains("核心温度: 67°C"))
        XCTAssertTrue(report.contains("风扇转速: 1800 RPM  SMC"))
        XCTAssertTrue(report.contains("热状态: 略热"))
    }

    private func snapshot() -> SystemSnapshot {
        SystemSnapshot(
            memory: MemorySnapshot(
                totalGB: 16,
                usedGB: 11.2,
                usedPercent: 70,
                availableGB: 4.8,
                activeGB: 6.2,
                wiredGB: 3.1,
                compressedGB: 1.4,
                pressure: MemoryPressureSnapshot(
                    score: 62,
                    level: .warning,
                    availableRatio: 0.3,
                    compressedRatio: 0.0875,
                    wiredRatio: 0.19375,
                    swapUsedGB: 0.7,
                    swapOutsPerSecond: 125
                )
            ),
            cpuUsage: 23,
            coreTemperatureC: 67,
            fan: FanSpeedSnapshot(speedsRPM: [1_800], isFanless: false, source: "SMC"),
            thermalState: .fair,
            updatedAt: Date(timeIntervalSince1970: 1_749_360_000)
        )
    }
}
