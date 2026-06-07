import Foundation

public struct GitHubRelease: Decodable {
    public let tagName: String
    public let name: String?
    public let body: String?
    public let htmlURL: URL
    public let assets: [GitHubReleaseAsset]

    public init(tagName: String, name: String?, body: String?, htmlURL: URL, assets: [GitHubReleaseAsset]) {
        self.tagName = tagName
        self.name = name
        self.body = body
        self.htmlURL = htmlURL
        self.assets = assets
    }

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case body
        case htmlURL = "html_url"
        case assets
    }

    public var versionText: String {
        tagName.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
    }

    public var bodyText: String {
        let trimmedBody = body?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmedBody.isEmpty ? "这个版本没有填写更新说明。" : trimmedBody
    }

    public func preferredInstallAssets(prefix: String, version: String) -> [UpdateInstallAsset] {
        var installAssets: [UpdateInstallAsset] = []
        if let zipAsset = preferredAppZipAsset(prefix: prefix, version: version) {
            installAssets.append(UpdateInstallAsset(kind: .appZip, asset: zipAsset))
        }

        if let dmgAsset = preferredDMGAsset(prefix: prefix, version: version) {
            installAssets.append(UpdateInstallAsset(kind: .dmg, asset: dmgAsset))
        }

        return installAssets
    }

    private func preferredAppZipAsset(prefix: String, version: String) -> GitHubReleaseAsset? {
        let exactName = "\(prefix)-\(version).app.zip"
        if let exactAsset = assets.first(where: { $0.name == exactName }) {
            return exactAsset
        }

        return assets.first { asset in
            asset.name.hasSuffix(".app.zip") && !asset.name.hasSuffix(".sha256")
        }
    }

    private func preferredDMGAsset(prefix: String, version: String) -> GitHubReleaseAsset? {
        let exactName = "\(prefix)-\(version).dmg"
        if let exactAsset = assets.first(where: { $0.name == exactName }) {
            return exactAsset
        }

        return assets.first { asset in
            asset.name.hasSuffix(".dmg") && !asset.name.hasSuffix(".sha256")
        }
    }

    public func checksumAsset(for installAsset: GitHubReleaseAsset) -> GitHubReleaseAsset? {
        assets.first { $0.name == "\(installAsset.name).sha256" }
            ?? assets.first { $0.name.hasSuffix(".sha256") && $0.name.hasPrefix(installAsset.name) }
    }
}
