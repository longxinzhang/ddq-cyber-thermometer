import Foundation

public struct ProcessCPUUsage: Equatable, Sendable {
    public let pid: Int32
    public let name: String
    public let cpuUsage: Double

    public init(pid: Int32, name: String, cpuUsage: Double) {
        self.pid = pid
        self.name = name
        self.cpuUsage = cpuUsage
    }
}
