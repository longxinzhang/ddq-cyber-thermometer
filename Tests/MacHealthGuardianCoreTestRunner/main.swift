import Foundation
import MacHealthGuardianCore

struct TestFailure: Error, CustomStringConvertible {
    let message: String

    var description: String {
        message
    }
}

func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() {
        throw TestFailure(message: message)
    }
}

func testReleaseVersionComparison() throws {
    try expect(ReleaseVersion("0.4.0") < ReleaseVersion("0.4.1"), "0.4.0 should be less than 0.4.1")
    try expect(ReleaseVersion("v1.10.0") > ReleaseVersion("v1.9.9"), "v1.10.0 should be greater than v1.9.9")
    try expect(ReleaseVersion("1.2") == ReleaseVersion("1.2.0"), "missing version components should compare as zero")
}

func testReleaseAssetSelection() throws {
    let release = makeRelease(assets: [
        makeAsset("DDQs-Cyber-Thermometer-1.2.3.dmg"),
        makeAsset("DDQs-Cyber-Thermometer-1.2.3.app.zip"),
        makeAsset("DDQs-Cyber-Thermometer-1.2.3.app.zip.sha256")
    ])

    let assets = release.preferredInstallAssets(
        prefix: "DDQs-Cyber-Thermometer",
        version: "1.2.3"
    )

    try expect(assets.map(\.kind) == [.appZip, .dmg], "install assets should prefer app zip before dmg")
    try expect(assets.first?.asset.name == "DDQs-Cyber-Thermometer-1.2.3.app.zip", "first install asset should be app zip")
}

func testReleaseAssetDMGFallback() throws {
    let release = makeRelease(assets: [
        makeAsset("DDQs-Cyber-Thermometer-1.2.3.dmg")
    ])

    let assets = release.preferredInstallAssets(
        prefix: "DDQs-Cyber-Thermometer",
        version: "1.2.3"
    )

    try expect(assets.map(\.kind) == [.dmg], "dmg should be used when app zip is missing")
}

func testChecksumAssetSelection() throws {
    let zip = makeAsset("DDQs-Cyber-Thermometer-1.2.3.app.zip")
    let release = makeRelease(assets: [
        zip,
        makeAsset("DDQs-Cyber-Thermometer-1.2.3.app.zip.sha256")
    ])

    try expect(
        release.checksumAsset(for: zip)?.name == "DDQs-Cyber-Thermometer-1.2.3.app.zip.sha256",
        "checksum asset should match the install asset name"
    )
}

func testReleaseAtomParsing() throws {
    let xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <feed>
      <entry>
        <title>DDQ's Cyber Thermometer v1.2.3</title>
        <link rel="alternate" href="https://github.com/owner/repo/releases/tag/v1.2.3" />
        <content type="html">&lt;p&gt;Fixed update checks&lt;/p&gt;</content>
      </entry>
    </feed>
    """

    guard let entry = ReleaseAtomParser.parseFirstEntry(from: Data(xml.utf8)) else {
        throw TestFailure(message: "release atom entry should parse")
    }

    try expect(entry.title == "DDQ's Cyber Thermometer v1.2.3", "atom title should parse")
    try expect(entry.htmlURL?.absoluteString == "https://github.com/owner/repo/releases/tag/v1.2.3", "atom release URL should parse")
    try expect(entry.contentHTML.contains("Fixed update checks"), "atom content should parse")
}

func testVMStatParsing() throws {
    let output = """
    Mach Virtual Memory Statistics: (page size of 16384 bytes)
    Pages free:                               1234.
    Pages active:                             567.
    Pages speculative:                        89.
    Pages occupied by compressor:             42.
    """

    let pages = VMStatParser.pages(from: output)

    try expect(VMStatParser.pageSize(from: output) == 16_384, "vm_stat page size should parse")
    try expect(pages["Pages free"] == 1_234, "free pages should parse")
    try expect(pages["Pages active"] == 567, "active pages should parse")
    try expect(pages["Pages speculative"] == 89, "speculative pages should parse")
    try expect(pages["Pages occupied by compressor"] == 42, "compressed pages should parse")
}

func testFormatting() throws {
    try expect(42.4.percentText == "42%", "percent text should round")
    try expect(42.5.shortPercentText == "43%", "short percent text should round")
    try expect(8.25.gbText == "8.2 GB", "small GB value should keep one decimal")
    try expect(128.0.gbText == "128 GB", "large GB value should round to an integer")
}

func makeRelease(assets: [GitHubReleaseAsset]) -> GitHubRelease {
    GitHubRelease(
        tagName: "v1.2.3",
        name: "Release",
        body: "Notes",
        htmlURL: URL(string: "https://example.com/releases/tag/v1.2.3")!,
        assets: assets
    )
}

func makeAsset(_ name: String) -> GitHubReleaseAsset {
    GitHubReleaseAsset(
        name: name,
        browserDownloadURL: URL(string: "https://example.com/\(name)")!,
        digest: nil
    )
}

let tests: [(String, () throws -> Void)] = [
    ("ReleaseVersion comparison", testReleaseVersionComparison),
    ("Release asset selection", testReleaseAssetSelection),
    ("Release asset DMG fallback", testReleaseAssetDMGFallback),
    ("Checksum asset selection", testChecksumAssetSelection),
    ("Release Atom parsing", testReleaseAtomParsing),
    ("VMStat parsing", testVMStatParsing),
    ("Formatting", testFormatting)
]

for (name, test) in tests {
    try test()
    print("PASS \(name)")
}

print("All MacHealthGuardianCore tests passed")
