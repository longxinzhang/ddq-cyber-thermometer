import Foundation

struct QuickLink: Codable, Equatable {
    var title: String
    var urlString: String

    var url: URL? {
        URL(string: urlString)
    }

    init(title: String, urlString: String) {
        self.title = title
        self.urlString = urlString
    }

    init?(title: String, rawURLString: String) {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty,
              let url = Self.normalizedURL(from: rawURLString)
        else {
            return nil
        }

        self.title = cleanTitle
        self.urlString = url.absoluteString
    }

    static func normalizedURL(from text: String) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let candidate = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        guard let url = URL(string: candidate),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              url.host != nil
        else {
            return nil
        }

        return url
    }
}
