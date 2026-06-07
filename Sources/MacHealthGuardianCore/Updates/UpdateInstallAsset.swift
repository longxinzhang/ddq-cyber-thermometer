import Foundation

public struct UpdateInstallAsset {
    public let kind: UpdatePackageKind
    public let asset: GitHubReleaseAsset

    public init(kind: UpdatePackageKind, asset: GitHubReleaseAsset) {
        self.kind = kind
        self.asset = asset
    }
}

public enum UpdatePackageKind: Equatable {
    case appZip
    case dmg
}
