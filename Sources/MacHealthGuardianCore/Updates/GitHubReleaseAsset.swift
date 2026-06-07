import Foundation

public struct GitHubReleaseAsset: Decodable {
    public let name: String
    public let browserDownloadURL: URL
    public let digest: String?

    public init(name: String, browserDownloadURL: URL, digest: String?) {
        self.name = name
        self.browserDownloadURL = browserDownloadURL
        self.digest = digest
    }

    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadURL = "browser_download_url"
        case digest
    }
}
