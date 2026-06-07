import Foundation
import MacHealthGuardianCore

struct AppDiagnosticReport {
    static func text(
        snapshot: SystemSnapshot,
        appVersionTitle: String = AppVersion.menuTitle,
        operatingSystem: String = ProcessInfo.processInfo.operatingSystemVersionString,
        architecture: String = currentArchitecture
    ) -> String {
        [
            "动动枪赛博体温计诊断信息",
            appVersionTitle,
            "系统: \(operatingSystem)",
            "架构: \(architecture)",
            "采样时间: \(snapshot.updatedAt.fullTimeText)",
            "",
            "内存压力: \(snapshot.memory.pressure.level.displayText) \(snapshot.memory.pressure.scoreText)",
            "内存占用: \(snapshot.memory.usedPercent.percentText) (\(snapshot.memory.usedGB.gbText) / \(snapshot.memory.totalGB.gbText))",
            "可用内存: \(snapshot.memory.availableGB.gbText)",
            "活跃内存: \(snapshot.memory.activeGB.gbText)",
            "固定内存: \(snapshot.memory.wiredGB.gbText)",
            "压缩内存: \(snapshot.memory.compressedGB.gbText)",
            "交换空间: \(snapshot.memory.pressure.swapUsedGB.gbText)",
            "Swap Out 速率: \(snapshot.memory.pressure.swapOutsPerSecond.pagesPerSecondText)",
            "",
            "CPU 占用: \(snapshot.cpuUsage.percentText)",
            "核心温度: \(snapshot.temperatureText)",
            "风扇转速: \(snapshot.fan.displayText)",
            "热状态: \(snapshot.thermalStateText)"
        ].joined(separator: "\n")
    }

    private static var currentArchitecture: String {
        #if arch(arm64)
        return "arm64"
        #elseif arch(x86_64)
        return "x86_64"
        #else
        return "unknown"
        #endif
    }
}

private extension Double {
    var pagesPerSecondText: String {
        "\(Int(self.rounded())) pages/s"
    }
}
