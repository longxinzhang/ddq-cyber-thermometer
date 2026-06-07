import Darwin
import Foundation

public final class SystemSampler: @unchecked Sendable {
    private let memorySampler: MemorySampler
    private let temperatureReader: TemperatureReader
    private let fanSpeedReader: FanSpeedReader
    private var previousCPUTicks: CPUTicks?

    public init() {
        let shell = Shell()
        self.memorySampler = MemorySampler(shell: shell)
        self.temperatureReader = TemperatureReader(shell: shell)
        self.fanSpeedReader = FanSpeedReader(shell: shell)
        self.previousCPUTicks = CPUTicks.current()
    }

    public func sample() -> SystemSnapshot {
        let updatedAt = Date()
        return SystemSnapshot(
            memory: memorySampler.sample(at: updatedAt),
            cpuUsage: readCPUUsage(),
            coreTemperatureC: temperatureReader.read(),
            fan: fanSpeedReader.read(),
            thermalState: ProcessInfo.processInfo.thermalState,
            updatedAt: updatedAt
        )
    }

    private func readCPUUsage() -> Double {
        guard let ticks = CPUTicks.current() else { return 0 }
        defer { previousCPUTicks = ticks }
        guard let previousCPUTicks else { return 0 }

        let user = ticks.user - previousCPUTicks.user
        let system = ticks.system - previousCPUTicks.system
        let nice = ticks.nice - previousCPUTicks.nice
        let idle = ticks.idle - previousCPUTicks.idle
        let total = user + system + nice + idle
        guard total > 0 else { return 0 }

        return min(100, max(0, Double(user + system + nice) / Double(total) * 100))
    }
}
