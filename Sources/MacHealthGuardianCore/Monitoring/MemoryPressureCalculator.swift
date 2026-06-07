import Foundation

public struct MemoryPressureCalculator {
    public static func calculate(
        totalGB: Double,
        availableGB: Double,
        compressedGB: Double,
        wiredGB: Double,
        swapUsedGB: Double,
        swapOutsPerSecond: Double
    ) -> MemoryPressureSnapshot {
        guard totalGB > 0 else { return .empty }

        let availableRatio = clamp(availableGB / totalGB)
        let compressedRatio = clamp(compressedGB / totalGB)
        let wiredRatio = clamp(wiredGB / totalGB)

        var score = availableRatioScore(availableRatio)
        score += min(20, compressedRatio * 120)

        if wiredRatio > 0.35 {
            score += 10
        }
        if wiredRatio > 0.50 {
            score += 10
        }

        if swapUsedGB > 0.5 {
            score += 10
        }
        if swapUsedGB > 2.0 {
            score += 10
        }

        if swapOutsPerSecond > 50 {
            score += 10
        }
        if swapOutsPerSecond > 500 {
            score += 15
        }

        let clampedScore = min(100, max(0, score))

        return MemoryPressureSnapshot(
            score: clampedScore,
            level: level(for: clampedScore),
            availableRatio: availableRatio,
            compressedRatio: compressedRatio,
            wiredRatio: wiredRatio,
            swapUsedGB: max(0, swapUsedGB),
            swapOutsPerSecond: max(0, swapOutsPerSecond)
        )
    }

    private static func availableRatioScore(_ ratio: Double) -> Double {
        switch ratio {
        case 0.35...:
            return 5
        case 0.20..<0.35:
            return 20
        case 0.10..<0.20:
            return 40
        case 0.05..<0.10:
            return 60
        default:
            return 75
        }
    }

    private static func level(for score: Double) -> MemoryPressureLevel {
        if score >= 80 {
            return .critical
        }
        if score >= 55 {
            return .warning
        }
        return .normal
    }

    private static func clamp(_ value: Double) -> Double {
        min(1, max(0, value))
    }
}
