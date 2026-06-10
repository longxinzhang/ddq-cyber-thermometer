import Foundation

public extension Date {
    var timeText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: self)
    }

    var fullTimeText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: self)
    }
}

public extension Double {
    var percentText: String {
        "\(Int(self.rounded()))%"
    }

    var shortPercentText: String {
        "\(Int(self.rounded()))%"
    }

    var gbText: String {
        if self >= 100 {
            return "\(Int(self.rounded())) GB"
        }
        return String(format: "%.1f GB", self)
    }

    var bytesPerSecondText: String {
        let bytes = max(0, self)
        let kilobytes = bytes / 1_024
        guard kilobytes >= 1 else { return "0 KB/s" }

        if kilobytes < 1_000 {
            if kilobytes < 10 {
                return String(format: "%.1f KB/s", kilobytes)
            }
            return "\(Int(kilobytes.rounded())) KB/s"
        }

        let megabytes = bytes / 1_048_576
        if megabytes < 10 {
            return String(format: "%.1f MB/s", megabytes)
        }
        return "\(Int(megabytes.rounded())) MB/s"
    }

    var compactBytesPerSecondText: String {
        let units = ["KB", "MB", "GB", "TB", "PB"]
        var value = max(0, self) / 1_000
        var unitIndex = 0

        while value >= 100, unitIndex < units.count - 1 {
            value /= 1_000
            unitIndex += 1
        }

        if unitIndex == units.count - 1, value >= 100 {
            value = 99.9
        }

        let numeric: String
        if value < 10 {
            numeric = String(format: "%.2f", value.truncated(decimalPlaces: 2))
        } else {
            numeric = String(format: "%.1f", value.truncated(decimalPlaces: 1))
        }
        return "\(numeric)\(units[unitIndex])"
    }

    private func truncated(decimalPlaces: Int) -> Double {
        let scale = pow(10, Double(decimalPlaces))
        return floor(self * scale) / scale
    }
}
