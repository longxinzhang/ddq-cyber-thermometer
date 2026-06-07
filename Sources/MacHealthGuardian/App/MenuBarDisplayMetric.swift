import Foundation

enum MenuBarDisplayMetric: String, CaseIterable {
    case memoryPressure
    case memoryUsage
    case cpuUsage

    var title: String {
        switch self {
        case .memoryPressure:
            return "内存压力"
        case .memoryUsage:
            return "内存占用"
        case .cpuUsage:
            return "CPU 占用"
        }
    }
}
