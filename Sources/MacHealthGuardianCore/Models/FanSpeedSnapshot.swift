import Foundation

public struct FanSpeedSnapshot: Sendable {
    public let speedsRPM: [Double]
    public let isFanless: Bool
    public let source: String?

    public static let unknown = FanSpeedSnapshot(speedsRPM: [], isFanless: false, source: nil)
    public static let fanless = FanSpeedSnapshot(speedsRPM: [], isFanless: true, source: "SMC")

    public var displayText: String {
        if isFanless {
            return "无风扇"
        }
        guard !speedsRPM.isEmpty else {
            return "未读取"
        }

        let values = speedsRPM
            .map { "\(Int($0.rounded())) RPM" }
            .joined(separator: " / ")
        if let source {
            return "\(values)  \(source)"
        }
        return values
    }
}
