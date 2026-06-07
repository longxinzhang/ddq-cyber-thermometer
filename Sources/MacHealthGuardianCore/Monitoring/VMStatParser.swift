import Foundation

public struct VMStatParser {
    public static func pages(from output: String) -> [String: Double] {
        var result: [String: Double] = [:]

        for line in output.split(separator: "\n") {
            let parts = line.split(separator: ":", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { continue }

            let key = parts[0].trimmingCharacters(in: .whitespaces)
            let numberText = parts[1]
                .replacingOccurrences(of: ".", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .split(separator: " ")
                .first
                .map(String.init)

            if let numberText, let value = Double(numberText) {
                result[key] = value
            }
        }

        return result
    }

    public static func pageSize(from output: String) -> Double? {
        guard let range = output.range(of: "page size of ") else { return nil }
        let suffix = output[range.upperBound...]
        let number = suffix.prefix { $0.isNumber }
        return Double(number)
    }
}
