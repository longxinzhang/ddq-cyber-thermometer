import AppKit
import CryptoKit
import Foundation
import MacHealthGuardianCore

@MainActor
final class UpdateController {
    private let owner = "longxinzhang"
    private let repository = "ddq-cyber-thermometer"
    private let assetPrefix = "DDQs-Cyber-Thermometer"
    private let installer = UpdateInstaller()
    private var isChecking = false

    func checkForUpdates(menuItem: NSMenuItem) {
        guard !isChecking else { return }

        isChecking = true
        let originalTitle = menuItem.title
        menuItem.title = "正在检查更新…"
        menuItem.isEnabled = false

        Task { @MainActor in
            defer {
                menuItem.title = originalTitle
                menuItem.isEnabled = true
                isChecking = false
            }

            do {
                let release = try await fetchLatestRelease()
                try await handle(release: release, menuItem: menuItem)
            } catch {
                showError(error)
            }
        }
    }

    private func handle(release: GitHubRelease, menuItem: NSMenuItem) async throws {
        let currentVersion = currentAppVersion()
        let latestVersion = release.versionText

        guard ReleaseVersion(latestVersion) > ReleaseVersion(currentVersion) else {
            showUpToDate(currentVersion: currentVersion, release: release)
            return
        }

        let installAssets = release.preferredInstallAssets(prefix: assetPrefix, version: latestVersion)
        guard !installAssets.isEmpty else {
            showMissingInstaller(release: release, version: latestVersion)
            return
        }

        guard askToInstall(release: release, currentVersion: currentVersion, latestVersion: latestVersion) else {
            return
        }

        var fallbackError: Error?
        for installAsset in installAssets {
            do {
                menuItem.title = "正在下载更新…"
                let downloadedPackage = try await downloadAndVerify(asset: installAsset.asset, release: release)

                menuItem.title = "正在准备安装…"
                try installer.startInstaller(
                    package: installAsset,
                    downloadedURL: downloadedPackage,
                    manualFallback: showManualInstall
                )
                return
            } catch UpdateError.httpStatus(let statusCode) where statusCode == 404 {
                fallbackError = UpdateError.httpStatus(statusCode)
                continue
            }
        }

        if let fallbackError {
            throw fallbackError
        }
    }

    private func fetchLatestRelease() async throws -> GitHubRelease {
        guard let url = URL(string: "https://github.com/\(owner)/\(repository)/releases.atom") else {
            throw UpdateError.invalidReleaseURL
        }

        var request = URLRequest(url: url)
        request.setValue("application/atom+xml", forHTTPHeaderField: "Accept")
        request.setValue("DDQ-Cyber-Thermometer/\(currentAppVersion())", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            try validate(response: response)

            if let entry = ReleaseAtomParser.parseFirstEntry(from: data),
               let htmlURL = entry.htmlURL,
               let tagName = tagName(fromReleaseURL: htmlURL) {
                return GitHubRelease(
                    tagName: tagName,
                    name: entry.title,
                    body: plainText(fromReleaseHTML: entry.contentHTML),
                    htmlURL: htmlURL,
                    assets: releaseAssets(tagName: tagName)
                )
            }
        } catch {
            return try await fetchLatestReleaseFromRedirect()
        }

        return try await fetchLatestReleaseFromRedirect()
    }

    private func fetchLatestReleaseFromRedirect() async throws -> GitHubRelease {
        guard let url = URL(string: "https://github.com/\(owner)/\(repository)/releases/latest") else {
            throw UpdateError.invalidReleaseURL
        }

        var request = URLRequest(url: url)
        request.setValue("DDQ-Cyber-Thermometer/\(currentAppVersion())", forHTTPHeaderField: "User-Agent")

        let (_, response) = try await URLSession.shared.data(for: request)
        try validate(response: response)

        guard let finalURL = response.url,
              let tagName = tagName(fromReleaseURL: finalURL)
        else {
            throw UpdateError.invalidReleaseFeed
        }

        return GitHubRelease(
            tagName: tagName,
            name: "DDQ's Cyber Thermometer \(tagName)",
            body: nil,
            htmlURL: finalURL,
            assets: releaseAssets(tagName: tagName)
        )
    }

    private func releaseAssets(tagName: String) -> [GitHubReleaseAsset] {
        let version = tagName.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
        let names = [
            "\(assetPrefix)-\(version).app.zip",
            "\(assetPrefix)-\(version).app.zip.sha256",
            "\(assetPrefix)-\(version).dmg",
            "\(assetPrefix)-\(version).dmg.sha256"
        ]

        return names.compactMap { name in
            guard let url = URL(string: "https://github.com/\(owner)/\(repository)/releases/download/\(tagName)/\(name)") else {
                return nil
            }
            return GitHubReleaseAsset(name: name, browserDownloadURL: url, digest: nil)
        }
    }

    private func tagName(fromReleaseURL url: URL) -> String? {
        guard let tagIndex = url.pathComponents.lastIndex(of: "tag"),
              tagIndex + 1 < url.pathComponents.count
        else {
            return nil
        }

        return url.pathComponents[tagIndex + 1]
    }

    private func plainText(fromReleaseHTML html: String) -> String {
        var text = html
        let replacements = [
            (#"(?i)<br\s*/?>"#, "\n"),
            (#"(?i)</p>"#, "\n\n"),
            (#"(?i)<li>"#, "- "),
            (#"(?i)</li>"#, "\n"),
            (#"(?i)</h[1-6]>"#, "\n\n"),
            (#"(?s)<[^>]+>"#, "")
        ]

        for (pattern, replacement) in replacements {
            text = text.replacingOccurrences(of: pattern, with: replacement, options: .regularExpression)
        }

        text = htmlUnescape(text)
        text = text
            .replacingOccurrences(of: #"[ \t]+\n"#, with: "\n", options: .regularExpression)
            .replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func htmlUnescape(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&amp;", with: "&")
    }

    private func downloadAndVerify(asset: GitHubReleaseAsset, release: GitHubRelease) async throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DDQCyberThermometerUpdates", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let dmgURL = try await download(asset: asset, into: directory)

        var expectedChecksum = normalizedSHA256(asset.digest)
        if let checksumAsset = release.checksumAsset(for: asset) {
            let checksumURL = try await download(asset: checksumAsset, into: directory)
            let checksumText = try String(contentsOf: checksumURL, encoding: .utf8)
            guard let checksum = normalizedSHA256(checksumText) else {
                throw UpdateError.invalidChecksumFile
            }
            expectedChecksum = checksum
        }

        if let expectedChecksum {
            let actualChecksum = try sha256Hex(for: dmgURL)
            guard actualChecksum == expectedChecksum else {
                throw UpdateError.checksumMismatch(expected: expectedChecksum, actual: actualChecksum)
            }
        }

        return dmgURL
    }

    private func download(asset: GitHubReleaseAsset, into directory: URL) async throws -> URL {
        var request = URLRequest(url: asset.browserDownloadURL)
        request.setValue("DDQ-Cyber-Thermometer/\(currentAppVersion())", forHTTPHeaderField: "User-Agent")

        let (temporaryURL, response) = try await URLSession.shared.download(for: request)
        try validate(response: response)

        let safeName = (asset.name as NSString).lastPathComponent
        let destinationURL = directory.appendingPathComponent(safeName)
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }
        try FileManager.default.moveItem(at: temporaryURL, to: destinationURL)
        return destinationURL
    }

    private func validate(response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else { return }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw UpdateError.httpStatus(httpResponse.statusCode)
        }
    }

    private func askToInstall(release: GitHubRelease, currentVersion: String, latestVersion: String) -> Bool {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "发现新版本 v\(latestVersion)"
        alert.informativeText = "当前版本 v\(currentVersion)。下载后会自动校验更新包，退出当前 App，替换为新版后重新打开。"
        alert.addButton(withTitle: "下载并安装")
        alert.addButton(withTitle: "稍后")
        alert.addButton(withTitle: "打开 Release")
        alert.accessoryView = releaseNotesView(text: release.bodyText)

        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()
        if response == .alertThirdButtonReturn {
            NSWorkspace.shared.open(release.htmlURL)
            return false
        }
        return response == .alertFirstButtonReturn
    }

    private func showUpToDate(currentVersion: String, release: GitHubRelease) {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "已经是最新版本"
        alert.informativeText = "当前版本 v\(currentVersion)，GitHub 最新版本是 \(release.tagName)。"
        alert.addButton(withTitle: "好")

        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    private func showMissingInstaller(release: GitHubRelease, version: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "没有找到可安装的更新包"
        alert.informativeText = "GitHub 最新版本是 v\(version)，但 Release 里没有找到 \(assetPrefix)-\(version).app.zip 或 \(assetPrefix)-\(version).dmg。"
        alert.addButton(withTitle: "打开 Release")
        alert.addButton(withTitle: "好")

        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(release.htmlURL)
        }
    }

    private func showManualInstall(packageURL: URL) {
        NSWorkspace.shared.open(packageURL)

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "需要手动安装"
        alert.informativeText = "当前运行的不是 .app 包，无法自动替换。已打开下载好的更新包，请手动安装。"
        alert.addButton(withTitle: "好")

        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    private func showError(_ error: Error) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "检查更新失败"
        alert.informativeText = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        alert.addButton(withTitle: "好")

        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    private func releaseNotesView(text: String) -> NSView {
        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 460, height: 220))
        scrollView.borderType = .bezelBorder
        scrollView.hasVerticalScroller = true

        let textView = NSTextView(frame: scrollView.bounds)
        textView.autoresizingMask = [.width]
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.font = NSFont.systemFont(ofSize: 12.5)
        textView.string = text

        scrollView.documentView = textView
        return scrollView
    }

    private func currentAppVersion() -> String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    private func sha256Hex(for fileURL: URL) throws -> String {
        let data = try Data(contentsOf: fileURL)
        return SHA256.hash(data: data)
            .map { String(format: "%02x", $0) }
            .joined()
    }

    private func normalizedSHA256(_ text: String?) -> String? {
        guard let text else { return nil }
        let lowercased = text.lowercased()
        if let range = lowercased.range(of: #"[a-f0-9]{64}"#, options: .regularExpression) {
            return String(lowercased[range])
        }
        return nil
    }
}
