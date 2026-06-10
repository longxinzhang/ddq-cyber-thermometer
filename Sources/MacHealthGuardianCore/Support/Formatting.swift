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
        let bytes = max(0, self)
        let kilobytes = bytes / 1_024
        guard kilobytes >= 1 else { return "0KB" }

        if kilobytes < 1_000 {
            if kilobytes < 10 {
                return String(format: "%.1fKB", kilobytes)
            }
            return "\(Int(kilobytes.rounded()))KB"
        }

        let megabytes = bytes / 1_048_576
        if megabytes < 10 {
            return String(format: "%.1fMB", megabytes)
        }
        return "\(Int(megabytes.rounded()))MB"
    }
}
