import Foundation

public struct SystemSnapshot: Sendable {
    public let memory: MemorySnapshot
    public let network: NetworkSnapshot
    public let cpuUsage: Double
    public let coreTemperatureC: Double?
    public let fan: FanSpeedSnapshot
    public let thermalState: ProcessInfo.ThermalState
    public let updatedAt: Date

    public static var placeholder: SystemSnapshot {
        SystemSnapshot(
            memory: .empty,
            network: .empty,
            cpuUsage: 0,
            coreTemperatureC: nil,
            fan: .unknown,
            thermalState: .nominal,
            updatedAt: Date()
        )
    }

    public var temperatureText: String {
        guard let coreTemperatureC else { return "--°C" }
        return "\(Int(coreTemperatureC.rounded()))°C"
    }

    public var temperatureShortText: String {
        guard let coreTemperatureC else { return "--" }
        return "\(Int(coreTemperatureC.rounded()))°"
    }

    public var temperatureFillFraction: Double {
        guard let coreTemperatureC else { return 0.08 }
        return min(1, max(0, (coreTemperatureC - 35) / 65))
    }

    public var thermalStateText: String {
        switch thermalState {
        case .nominal:
            return "热状态正常"
        case .fair:
            return "略热"
        case .serious:
            return "偏热"
        case .critical:
            return "过热"
        @unknown default:
            return "热状态未知"
        }
    }

    public var toolTipText: String {
        "内存压力 \(memory.pressure.scoreText)  内存 \(memory.usedPercent.percentText)  CPU \(cpuUsage.percentText)  核心温度 \(temperatureText)  \(network.displayText)"
    }

    public var summaryText: String {
        [
            "内存压力: \(memory.pressure.level.displayText) \(memory.pressure.scoreText)",
            "内存占用: \(memory.usedPercent.percentText) (\(memory.usedGB.gbText) / \(memory.totalGB.gbText))",
            "可用内存: \(memory.availableGB.gbText)",
            "压缩内存: \(memory.compressedGB.gbText)",
            "交换空间: \(memory.pressure.swapUsedGB.gbText)",
            "网络流量: \(network.displayText)",
            "网络接口: \(network.interfaceText)",
            "CPU 占用: \(cpuUsage.percentText)",
            "核心温度: \(temperatureText)",
            "风扇转速: \(fan.displayText)",
            "热状态: \(thermalStateText)",
            "更新时间: \(updatedAt.fullTimeText)"
        ].joined(separator: "\n")
    }
}
