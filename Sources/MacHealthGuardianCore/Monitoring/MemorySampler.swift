import Darwin
import Foundation

final class MemorySampler: @unchecked Sendable {
    private let shell: Shell
    private var previousSwapouts: Double?
    private var previousSampleDate: Date?

    init(shell: Shell) {
        self.shell = shell
    }

    func sample(at date: Date = Date()) -> MemorySnapshot {
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
        let swapouts = pages["Swapouts"] ?? 0

        let totalGB = Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824
        let freeGB = Double(freePages + speculativePages + purgeablePages) * pageSize / 1_073_741_824
        let inactiveGB = Double(inactivePages) * pageSize / 1_073_741_824
        let wiredGB = Double(wiredPages) * pageSize / 1_073_741_824
        let compressedGB = Double(compressedPages) * pageSize / 1_073_741_824
        let activeGB = Double(activePages) * pageSize / 1_073_741_824
        let availableGB = min(totalGB, max(0, freeGB + inactiveGB * 0.65))
        let usedGB = min(totalGB, max(0, totalGB - availableGB))
        let usedPercent = totalGB > 0 ? usedGB / totalGB * 100 : 0
        let swapUsedGB = readSwapUsedGB()
        let swapOutsPerSecond = calculateSwapOutRate(currentSwapouts: swapouts, date: date)

        let pressure = MemoryPressureCalculator.calculate(
            totalGB: totalGB,
            availableGB: availableGB,
            compressedGB: compressedGB,
            wiredGB: wiredGB,
            swapUsedGB: swapUsedGB,
            swapOutsPerSecond: swapOutsPerSecond
        )

        return MemorySnapshot(
            totalGB: totalGB,
            usedGB: usedGB,
            usedPercent: usedPercent,
            availableGB: availableGB,
            activeGB: activeGB,
            wiredGB: wiredGB,
            compressedGB: compressedGB,
            pressure: pressure
        )
    }

    private func readSwapUsedGB() -> Double {
        let output = shell.run("/usr/sbin/sysctl", ["vm.swapusage"])
        return SwapUsageParser.usedGB(from: output) ?? 0
    }

    private func calculateSwapOutRate(currentSwapouts: Double, date: Date) -> Double {
        defer {
            previousSwapouts = currentSwapouts
            previousSampleDate = date
        }

        guard let previousSwapouts,
              let previousSampleDate
        else {
            return 0
        }

        let elapsed = date.timeIntervalSince(previousSampleDate)
        guard elapsed > 0 else { return 0 }

        return max(0, currentSwapouts - previousSwapouts) / elapsed
    }
}
