import Foundation

public struct ReleaseVersion: Comparable {
    private let components: [Int]

    public init(_ text: String) {
        let versionText = text.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
        let numbers = versionText
            .split { !$0.isNumber }
            .compactMap { Int($0) }
        self.components = numbers.isEmpty ? [0] : numbers
    }

    public static func == (lhs: ReleaseVersion, rhs: ReleaseVersion) -> Bool {
        let count = max(lhs.components.count, rhs.components.count)
        for index in 0..<count {
            let left = index < lhs.components.count ? lhs.components[index] : 0
            let right = index < rhs.components.count ? rhs.components[index] : 0
            if left != right {
                return false
            }
        }
        return true
    }

    public static func < (lhs: ReleaseVersion, rhs: ReleaseVersion) -> Bool {
        let count = max(lhs.components.count, rhs.components.count)
        for index in 0..<count {
            let left = index < lhs.components.count ? lhs.components[index] : 0
            let right = index < rhs.components.count ? rhs.components[index] : 0
            if left != right {
                return left < right
            }
        }
        return false
    }
}
