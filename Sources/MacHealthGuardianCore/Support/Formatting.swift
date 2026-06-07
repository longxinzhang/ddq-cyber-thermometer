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
}
