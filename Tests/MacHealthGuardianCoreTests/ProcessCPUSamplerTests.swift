import XCTest
@testable import MacHealthGuardianCore

final class ProcessCPUSamplerTests: XCTestCase {
    func testRanksRecentCPUUsageAndIncludesSystemTime() {
        let previous = sample(at: 1_000_000_000, processes: [
            1: reading(user: 5_000_000_000),
            2: reading(user: 1_000_000_000),
            3: reading(user: 2_000_000_000),
            4: reading(user: 0)
        ])
        let current = sample(at: 2_000_000_000, processes: [
            1: reading(user: 5_010_000_000),
            2: reading(user: 1_100_000_000, system: 400_000_000),
            3: reading(user: 2_200_000_000),
            4: reading(user: 300_000_000)
        ])

        let result = current.topProcesses(since: previous)

        XCTAssertEqual(result.map(\.pid), [2, 4, 3])
        XCTAssertEqual(result.map(\.cpuUsage), [50, 30, 20])
    }

    func testPreservesMulticorePercentagesOverOneHundred() {
        let previous = sample(at: 1_000_000_000, processes: [1: reading(user: 0)])
        let current = sample(at: 3_000_000_000, processes: [1: reading(user: 5_000_000_000)])

        XCTAssertEqual(current.topProcesses(since: previous).first?.cpuUsage, 250)
    }

    func testSkipsReusedPIDsNewProcessesAndExitedProcesses() {
        let previous = sample(at: 1_000_000_000, processes: [
            1: reading(user: 100, startedAt: 1),
            2: reading(user: 100),
            3: reading(user: 100)
        ])
        let current = sample(at: 2_000_000_000, processes: [
            1: reading(user: 1_000_000_000, startedAt: 2),
            3: reading(user: 200),
            4: reading(user: 1_000_000_000)
        ])

        XCTAssertEqual(current.topProcesses(since: previous).map(\.pid), [3])
    }

    func testRejectsReversedCountersAndInvalidTimeIntervals() {
        let previous = sample(at: 2_000_000_000, processes: [
            1: reading(user: 100),
            2: reading(user: 100, system: 100)
        ])
        let current = sample(at: 3_000_000_000, processes: [
            1: reading(user: 50),
            2: reading(user: 200, system: 50)
        ])

        XCTAssertTrue(current.topProcesses(since: previous).isEmpty)
        XCTAssertTrue(previous.topProcesses(since: current).isEmpty)
        XCTAssertTrue(previous.topProcesses(since: previous).isEmpty)
    }

    func testHandlesEmptySamplesAndOrdersTiesByPID() {
        let previous = sample(at: 1, processes: [2: reading(user: 0), 1: reading(user: 0)])
        let current = sample(at: 2, processes: [2: reading(user: 0), 1: reading(user: 0)])

        XCTAssertEqual(current.topProcesses(since: previous).map(\.pid), [1, 2])
        XCTAssertTrue(current.topProcesses(since: previous, limit: 0).isEmpty)
        XCTAssertTrue(sample(at: 3, processes: [:]).topProcesses(since: current).isEmpty)
    }

    private func sample(at time: UInt64, processes: [Int32: ProcessCPUReading]) -> ProcessCPUSample {
        ProcessCPUSample(uptimeTicks: time, processes: processes)
    }

    private func reading(user: UInt64, system: UInt64 = 0, startedAt: UInt64 = 1) -> ProcessCPUReading {
        ProcessCPUReading(name: "Test Process", startedAt: startedAt, userTicks: user, systemTicks: system)
    }
}
