import Foundation

struct AppVersion {
    static var menuTitle: String {
        displayText(infoDictionary: Bundle.main.infoDictionary)
    }

    static func displayText(infoDictionary: [String: Any]?) -> String {
        if let version = infoDictionary?["CFBundleShortVersionString"] as? String,
           !version.isEmpty {
            return "版本 \(version)"
        }

        if let build = infoDictionary?["CFBundleVersion"] as? String,
           !build.isEmpty {
            return "版本 \(build)"
        }

        return "版本 --"
    }
}
