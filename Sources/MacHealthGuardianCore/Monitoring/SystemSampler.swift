import Darwin
import Foundation

public final class SystemSampler: @unchecked Sendable {
    private let shell: Shell
    private let temperatureReader: TemperatureReader
    private let fanSpeedReader: FanSpeedReader
    private var previousCPUTicks: CPUTicks?

    public init() {
        let shell = Shell()
        self.shell = shell
        self.temperatureReader = TemperatureReader(shell: shell)
        self.fanSpeedReader = FanSpeedReader(shell: shell)
        self.previousCPUTicks = CPUTicks.current()
    }

    public func sample() -> SystemSnapshot {
        SystemSnapshot(
            memory: readMemory(),
            cpuUsage: readCPUUsage(),
            coreTemperatureC: temperatureReader.read(),
            fan: fanSpeedReader.read(),
            thermalState: ProcessInfo.processInfo.thermalState,
            updatedAt: Date()
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

    private func readMemory() -> MemorySnapshot {
        let output = shell.run("/usr/bin/vm_stat", [])
        let pageSize = VMStatParser.pageSize(from: output) ?? Double(getpagesize())
        let pages = VMStatParser.pages(from: output)

        let freePages = pages["Pages free"] ?? 0
        let speculativePages = pages["Pages speculative"] ?? 0
        let inactivePages = pages["Pages inactive"] ?? 0
        let wiredPages = pages["Pages wired down"] ?? 0
        let compressedPages = pages["Pages occupied by compressor"] ?? pages["Pages compressed"] ?? 0
        let purgeablePages = pages["Pages purgeable"] ?? 0
        let activePages = pages["Pages active"] ?? 0

        let totalGB = Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824
        let freeGB = Double(freePages + speculativePages + purgeablePages) * pageSize / 1_073_741_824
        let inactiveGB = Double(inactivePages) * pageSize / 1_073_741_824
        let wiredGB = Double(wiredPages) * pageSize / 1_073_741_824
        let compressedGB = Double(compressedPages) * pageSize / 1_073_741_824
        let activeGB = Double(activePages) * pageSize / 1_073_741_824
        let availableGB = min(totalGB, max(0, freeGB + inactiveGB * 0.65))
        let usedGB = min(totalGB, max(0, totalGB - availableGB))
        let usedPercent = totalGB > 0 ? usedGB / totalGB * 100 : 0

        return MemorySnapshot(
            totalGB: totalGB,
            usedGB: usedGB,
            usedPercent: usedPercent,
            availableGB: availableGB,
            activeGB: activeGB,
            wiredGB: wiredGB,
            compressedGB: compressedGB
        )
    }
}
