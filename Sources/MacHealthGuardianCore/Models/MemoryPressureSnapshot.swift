import Foundation

public enum MemoryPressureLevel: String, Sendable {
    case normal
    case warning
    case critical

    public var displayText: String {
        switch self {
        case .normal:
            return "正常"
        case .warning:
            return "偏高"
        case .critical:
            return "紧张"
        }
    }
}

public struct MemoryPressureSnapshot: Sendable {
    public let score: Double
    public let level: MemoryPressureLevel
    public let availableRatio: Double
    public let compressedRatio: Double
    public let wiredRatio: Double
    public let swapUsedGB: Double
    public let swapOutsPerSecond: Double

    public static let empty = MemoryPressureSnapshot(
        score: 0,
        level: .normal,
        availableRatio: 0,
        compressedRatio: 0,
        wiredRatio: 0,
        swapUsedGB: 0,
        swapOutsPerSecond: 0
    )

    public init(
        score: Double,
        level: MemoryPressureLevel,
        availableRatio: Double,
        compressedRatio: Double,
        wiredRatio: Double,
        swapUsedGB: Double,
        swapOutsPerSecond: Double
    ) {
        self.score = score
        self.level = level
        self.availableRatio = availableRatio
        self.compressedRatio = compressedRatio
        self.wiredRatio = wiredRatio
        self.swapUsedGB = swapUsedGB
        self.swapOutsPerSecond = swapOutsPerSecond
    }

    public var scoreText: String {
        score.percentText
    }
}
