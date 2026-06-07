import XCTest
@testable import MacHealthGuardianCore

final class GitHubReleaseTests: XCTestCase {
    func testPrefersAppZipBeforeDMG() {
        let release = makeRelease(assets: [
            makeAsset("DDQs-Cyber-Thermometer-1.2.3.dmg"),
            makeAsset("DDQs-Cyber-Thermometer-1.2.3.app.zip"),
            makeAsset("DDQs-Cyber-Thermometer-1.2.3.app.zip.sha256")
        ])

        let assets = release.preferredInstallAssets(
            prefix: "DDQs-Cyber-Thermometer",
            version: "1.2.3"
        )

        XCTAssertEqual(assets.map(\.kind), [.appZip, .dmg])
        XCTAssertEqual(assets.first?.asset.name, "DDQs-Cyber-Thermometer-1.2.3.app.zip")
    }

    func testFallsBackToDMGWhenZipIsMissing() {
        let release = makeRelease(assets: [
            makeAsset("DDQs-Cyber-Thermometer-1.2.3.dmg")
        ])

        let assets = release.preferredInstallAssets(
            prefix: "DDQs-Cyber-Thermometer",
            version: "1.2.3"
        )

        XCTAssertEqual(assets.map(\.kind), [.dmg])
        XCTAssertEqual(assets.first?.asset.name, "DDQs-Cyber-Thermometer-1.2.3.dmg")
    }

    func testFindsMatchingChecksumAsset() {
        let zip = makeAsset("DDQs-Cyber-Thermometer-1.2.3.app.zip")
        let release = makeRelease(assets: [
            zip,
            makeAsset("DDQs-Cyber-Thermometer-1.2.3.app.zip.sha256")
        ])

        XCTAssertEqual(
            release.checksumAsset(for: zip)?.name,
            "DDQs-Cyber-Thermometer-1.2.3.app.zip.sha256"
        )
    }

    private func makeRelease(assets: [GitHubReleaseAsset]) -> GitHubRelease {
        GitHubRelease(
            tagName: "v1.2.3",
            name: "Release",
            body: "Notes",
            htmlURL: URL(string: "https://example.com/releases/tag/v1.2.3")!,
            assets: assets
        )
    }

    private func makeAsset(_ name: String) -> GitHubReleaseAsset {
        GitHubReleaseAsset(
            name: name,
            browserDownloadURL: URL(string: "https://example.com/\(name)")!,
            digest: nil
        )
    }
}
