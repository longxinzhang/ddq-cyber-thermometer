import Foundation

public struct MemorySnapshot: Sendable {
    public let totalGB: Double
    public let usedGB: Double
    public let usedPercent: Double
    public let availableGB: Double
    public let activeGB: Double
    public let wiredGB: Double
    public let compressedGB: Double
    public let pressure: MemoryPressureSnapshot

    public static let empty = MemorySnapshot(
        totalGB: 0,
        usedGB: 0,
        usedPercent: 0,
        availableGB: 0,
        activeGB: 0,
        wiredGB: 0,
        compressedGB: 0,
        pressure: .empty
    )

    public init(
        totalGB: Double,
        usedGB: Double,
        usedPercent: Double,
        availableGB: Double,
        activeGB: Double,
        wiredGB: Double,
        compressedGB: Double,
        pressure: MemoryPressureSnapshot
    ) {
        self.totalGB = totalGB
        self.usedGB = usedGB
        self.usedPercent = usedPercent
        self.availableGB = availableGB
        self.activeGB = activeGB
        self.wiredGB = wiredGB
        self.compressedGB = compressedGB
        self.pressure = pressure
    }

    public var shortPercentText: String {
        usedPercent.shortPercentText
    }
}
