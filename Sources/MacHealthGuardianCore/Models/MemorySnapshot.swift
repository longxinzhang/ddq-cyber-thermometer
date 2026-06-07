import Foundation

public struct MemorySnapshot: Sendable {
    public let totalGB: Double
    public let usedGB: Double
    public let usedPercent: Double
    public let availableGB: Double
    public let activeGB: Double
    public let wiredGB: Double
    public let compressedGB: Double

    public static let empty = MemorySnapshot(
        totalGB: 0,
        usedGB: 0,
        usedPercent: 0,
        availableGB: 0,
        activeGB: 0,
        wiredGB: 0,
        compressedGB: 0
    )

    public var shortPercentText: String {
        usedPercent.shortPercentText
    }
}
