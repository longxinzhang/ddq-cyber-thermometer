import Foundation

public struct SwapUsageParser {
    public static func usedGB(from output: String) -> Double? {
        guard let range = output.range(of: #"used\s*=\s*"#, options: [.regularExpression, .caseInsensitive]) else {
            return nil
        }

        let suffix = output[range.upperBound...].trimmingCharacters(in: .whitespaces)
        let valueText = suffix.prefix { character in
            character.isNumber || character == "."
        }

        guard let value = Double(valueText) else {
            return nil
        }

        let unit = suffix
            .dropFirst(valueText.count)
            .trimmingCharacters(in: .whitespaces)
            .first
            .map { String($0).uppercased() } ?? "M"

        switch unit {
        case "T":
            return value * 1024
        case "G":
            return value
        case "K":
            return value / 1_048_576
        default:
            return value / 1024
        }
    }
}
