import AppKit
import CryptoKit
import Darwin
import Foundation
import IOKit
import ServiceManagement
import SwiftUI

@main
struct MacHealthGuardianApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        let arguments = CommandLine.arguments

        if arguments.contains("--help") {
            print("""
            DDQ's Cyber Thermometer / 动动枪赛博体温计

            Usage:
              MacHealthGuardian             Launch menu bar thermometer
              MacHealthGuardian --sample    Print one compact metrics sample
            """)
            Darwin.exit(0)
        }

        if arguments.contains("--sample") || arguments.contains("--doctor") {
            let sampler = SystemSampler()
            _ = sampler.sample()
            Thread.sleep(forTimeInterval: 1)
            print(sampler.sample().summaryText)
            Darwin.exit(0)
        }
    }

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let monitor = SystemMonitor()
    private let renderer = StatusImageRenderer()
    private let updateController = UpdateController()
    private let launchAtLoginController = LaunchAtLoginController()
    private let menu = NSMenu()
    private let memoryItem = NSMenuItem(title: "内存 --", action: nil, keyEquivalent: "")
    private let cpuItem = NSMenuItem(title: "CPU --", action: nil, keyEquivalent: "")
    private let temperatureItem = NSMenuItem(title: "核心温度 --", action: nil, keyEquivalent: "")
    private let fanItem = NSMenuItem(title: "风扇转速 --", action: nil, keyEquivalent: "")
    private let updatedItem = NSMenuItem(title: "等待刷新", action: nil, keyEquivalent: "")
    private let launchAtLoginItem = NSMenuItem(title: "开机启动", action: nil, keyEquivalent: "")
    private let updateItem = NSMenuItem(title: "检查更新…", action: nil, keyEquivalent: "")
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureMenu()

        let statusItem = NSStatusBar.system.statusItem(withLength: renderer.placeholderSize.width)
        self.statusItem = statusItem
        statusItem.menu = menu

        if let button = statusItem.button {
            button.imagePosition = .imageOnly
            button.imageScaling = .scaleNone
            button.toolTip = SystemSnapshot.placeholder.toolTipText
            let image = renderer.image(
                for: .placeholder,
                appearance: button.effectiveAppearance
            )
            statusItem.length = image.size.width
            button.image = image
        }

        monitor.onSnapshot = { [weak self] snapshot in
            self?.render(snapshot)
        }
        monitor.start()
    }

    private func configureMenu() {
        menu.delegate = self

        [memoryItem, cpuItem, temperatureItem, fanItem, updatedItem].forEach { item in
            item.isEnabled = false
        }

        menu.addItem(memoryItem)
        menu.addItem(cpuItem)
        menu.addItem(temperatureItem)
        menu.addItem(fanItem)
        menu.addItem(updatedItem)
        menu.addItem(.separator())

        launchAtLoginItem.action = #selector(toggleLaunchAtLogin)
        launchAtLoginItem.target = self
        menu.addItem(launchAtLoginItem)

        updateItem.action = #selector(checkForUpdates)
        updateItem.target = self
        menu.addItem(updateItem)

        let refreshItem = NSMenuItem(
            title: "刷新",
            action: #selector(refreshNow),
            keyEquivalent: "r"
        )
        refreshItem.target = self
        menu.addItem(refreshItem)

        let quitItem = NSMenuItem(
            title: "退出",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)
    }

    func menuWillOpen(_ menu: NSMenu) {
        updateLaunchAtLoginMenuItem()
    }

    private func render(_ snapshot: SystemSnapshot) {
        guard let button = statusItem?.button else { return }

        let image = renderer.image(for: snapshot, appearance: button.effectiveAppearance)
        statusItem?.length = image.size.width
        button.toolTip = snapshot.toolTipText
        button.image = image

        memoryItem.title = "内存占用 \(snapshot.memory.usedPercent.percentText)  \(snapshot.memory.usedGB.gbText) / \(snapshot.memory.totalGB.gbText)"
        cpuItem.title = "CPU 占用 \(snapshot.cpuUsage.percentText)"
        temperatureItem.title = "核心温度 \(snapshot.temperatureText)  \(snapshot.thermalStateText)"
        fanItem.title = "风扇转速 \(snapshot.fan.displayText)"
        updatedItem.title = "更新 \(snapshot.updatedAt.timeText)"
    }

    @objc private func refreshNow() {
        monitor.refresh()
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            try launchAtLoginController.setEnabled(!launchAtLoginController.isEnabled)
            updateLaunchAtLoginMenuItem()
        } catch {
            updateLaunchAtLoginMenuItem()
            showLaunchAtLoginError(error)
        }
    }

    @objc private func checkForUpdates() {
        updateController.checkForUpdates(menuItem: updateItem)
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }

    private func updateLaunchAtLoginMenuItem() {
        launchAtLoginItem.state = launchAtLoginController.isEnabled ? .on : .off
        launchAtLoginItem.isEnabled = launchAtLoginController.canToggle
    }

    private func showLaunchAtLoginError(_ error: Error) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "开机启动设置失败"
        alert.informativeText = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        alert.addButton(withTitle: "好")

        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}

final class LaunchAtLoginController {
    var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    var canToggle: Bool {
        let status = SMAppService.mainApp.status
        return status == .enabled || status == .notRegistered
    }

    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            if SMAppService.mainApp.status != .enabled {
                try SMAppService.mainApp.register()
            }
        } else {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            }
        }
    }
}

@MainActor
final class UpdateController {
    private let owner = "longxinzhang"
    private let repository = "ddq-cyber-thermometer"
    private let assetPrefix = "DDQs-Cyber-Thermometer"
    private let appBundleName = "动动枪赛博体温计.app"
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
                try startInstaller(package: installAsset, downloadedURL: downloadedPackage)
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

    private func startInstaller(package: UpdateInstallAsset, downloadedURL: URL) throws {
        let appURL = Bundle.main.bundleURL
        guard appURL.pathExtension == "app" else {
            showManualInstall(packageURL: downloadedURL)
            return
        }

        let scriptURL = try writeInstallerScript(package: package, downloadedURL: downloadedURL, appURL: appURL)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [scriptURL.path]
        try process.run()
        NSApplication.shared.terminate(nil)
    }

    private func writeInstallerScript(package: UpdateInstallAsset, downloadedURL: URL, appURL: URL) throws -> URL {
        let scriptURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ddq-cyber-thermometer-install-\(UUID().uuidString).sh")
        let pid = ProcessInfo.processInfo.processIdentifier
        let sourcePreparationScript: String
        let cleanupScript: String
        let manualFallbackScript: String

        switch package.kind {
        case .appZip:
            sourcePreparationScript = """
            EXTRACT_DIR="$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/ddq-update-extract.XXXXXX")"
            /usr/bin/ditto -x -k "$PACKAGE" "$EXTRACT_DIR" || fail
            SOURCE_APP="$EXTRACT_DIR/$APP_NAME"
            if [ ! -d "$SOURCE_APP" ]; then
              SOURCE_APP="$(/usr/bin/find "$EXTRACT_DIR" -maxdepth 2 -name "*.app" -type d | /usr/bin/head -n 1)"
            fi
            """
            cleanupScript = """
              if [ -n "$EXTRACT_DIR" ] && [ -d "$EXTRACT_DIR" ]; then
                /bin/rm -rf "$EXTRACT_DIR" >/dev/null 2>&1 || true
              fi
            """
            manualFallbackScript = """
              /usr/bin/open "$PACKAGE" >/dev/null 2>&1 || true
              /usr/bin/osascript -e 'display dialog "动动枪赛博体温计自动安装失败，已打开 ZIP。请解压后手动把 App 拖到 Applications 替换旧版本。" buttons {"好"} default button 1 with icon caution' >/dev/null 2>&1 || true
            """
        case .dmg:
            sourcePreparationScript = """
            PLIST="$(/usr/bin/mktemp "${TMPDIR:-/tmp}/ddq-update-mount.XXXXXX.plist")"
            /usr/bin/hdiutil attach "$PACKAGE" -nobrowse -readonly -noverify -plist > "$PLIST" || fail

            for index in 0 1 2 3 4; do
              MOUNT_POINT="$(/usr/libexec/PlistBuddy -c "Print :system-entities:$index:mount-point" "$PLIST" 2>/dev/null || true)"
              if [ -n "$MOUNT_POINT" ]; then
                break
              fi
            done

            if [ -z "$MOUNT_POINT" ]; then
              fail
            fi

            SOURCE_APP="$MOUNT_POINT/$APP_NAME"
            if [ ! -d "$SOURCE_APP" ]; then
              SOURCE_APP="$(/usr/bin/find "$MOUNT_POINT" -maxdepth 1 -name "*.app" -type d | /usr/bin/head -n 1)"
            fi
            """
            cleanupScript = """
              if [ -n "$MOUNT_POINT" ]; then
                /usr/bin/hdiutil detach "$MOUNT_POINT" -quiet >/dev/null 2>&1 || true
              fi
              if [ -n "$PLIST" ]; then
                /bin/rm -f "$PLIST" >/dev/null 2>&1 || true
              fi
            """
            manualFallbackScript = """
              /usr/bin/open "$PACKAGE" >/dev/null 2>&1 || true
              /usr/bin/osascript -e 'display dialog "动动枪赛博体温计自动安装失败，已打开 DMG。请手动把 App 拖到 Applications 替换旧版本。" buttons {"好"} default button 1 with icon caution' >/dev/null 2>&1 || true
            """
        }

        let content = """
        #!/bin/bash
        set -euo pipefail

        PACKAGE=\(downloadedURL.path.shellQuoted)
        TARGET_APP=\(appURL.path.shellQuoted)
        APP_NAME=\(appBundleName.shellQuoted)
        APP_PID=\(pid)
        LOG="${TMPDIR:-/tmp}/ddq-cyber-thermometer-update.log"
        MOUNT_POINT=""
        PLIST=""
        EXTRACT_DIR=""
        TMP_APP=""
        SOURCE_APP=""

        fail() {
        \(manualFallbackScript)
          exit 1
        }

        cleanup() {
        \(cleanupScript)
          if [ -n "$TMP_APP" ] && [ -d "$TMP_APP" ]; then
            /bin/rm -rf "$TMP_APP" >/dev/null 2>&1 || true
          fi
        }
        trap cleanup EXIT

        exec >> "$LOG" 2>&1
        echo "Starting DDQ Cyber Thermometer update at $(/bin/date)"

        for _ in {1..80}; do
          if ! /bin/ps -p "$APP_PID" >/dev/null 2>&1; then
            break
          fi
          /bin/sleep 0.5
        done

        \(sourcePreparationScript)
        if [ -z "$SOURCE_APP" ] || [ ! -d "$SOURCE_APP" ]; then
          fail
        fi

        TARGET_PARENT="$(/usr/bin/dirname "$TARGET_APP")"
        TMP_APP="$TARGET_PARENT/.ddq-cyber-thermometer-update-$$.app"

        /usr/bin/ditto "$SOURCE_APP" "$TMP_APP" || fail
        /usr/bin/codesign --verify --deep --strict "$TMP_APP" >/dev/null 2>&1 || true

        if [ -d "$TARGET_APP" ]; then
          /bin/rm -rf "$TARGET_APP" || fail
        fi
        /bin/mv "$TMP_APP" "$TARGET_APP" || fail
        TMP_APP=""

        /usr/bin/xattr -dr com.apple.quarantine "$TARGET_APP" >/dev/null 2>&1 || true
        /usr/bin/open "$TARGET_APP" >/dev/null 2>&1 || true
        /bin/rm -f "$PACKAGE" "$0" >/dev/null 2>&1 || true
        echo "Update finished at $(/bin/date)"
        """

        try content.write(to: scriptURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)
        return scriptURL
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

struct UpdateInstallAsset {
    let kind: UpdatePackageKind
    let asset: GitHubReleaseAsset
}

enum UpdatePackageKind {
    case appZip
    case dmg
}

struct ReleaseAtomEntry {
    var title = ""
    var contentHTML = ""
    var htmlURL: URL?
}

final class ReleaseAtomParser: NSObject, XMLParserDelegate {
    private var entries: [ReleaseAtomEntry] = []
    private var currentEntry: ReleaseAtomEntry?
    private var currentElement: String?
    private var buffer = ""

    static func parseFirstEntry(from data: Data) -> ReleaseAtomEntry? {
        let parserDelegate = ReleaseAtomParser()
        let parser = XMLParser(data: data)
        parser.delegate = parserDelegate
        guard parser.parse() else { return nil }
        return parserDelegate.entries.first
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        if elementName == "entry" {
            currentEntry = ReleaseAtomEntry()
            return
        }

        guard currentEntry != nil else { return }

        if elementName == "title" || elementName == "content" {
            currentElement = elementName
            buffer = ""
        } else if elementName == "link",
                  attributeDict["rel"] == "alternate",
                  let href = attributeDict["href"],
                  let url = URL(string: href) {
            currentEntry?.htmlURL = url
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard currentElement != nil else { return }
        buffer += string
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        guard currentEntry != nil else { return }

        if elementName == "title", currentElement == "title" {
            currentEntry?.title = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
            currentElement = nil
            buffer = ""
        } else if elementName == "content", currentElement == "content" {
            currentEntry?.contentHTML = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
            currentElement = nil
            buffer = ""
        } else if elementName == "entry", let entry = currentEntry {
            entries.append(entry)
            currentEntry = nil
        }
    }
}

struct GitHubRelease: Decodable {
    let tagName: String
    let name: String?
    let body: String?
    let htmlURL: URL
    let assets: [GitHubReleaseAsset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case body
        case htmlURL = "html_url"
        case assets
    }

    var versionText: String {
        tagName.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
    }

    var bodyText: String {
        let trimmedBody = body?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmedBody.isEmpty ? "这个版本没有填写更新说明。" : trimmedBody
    }

    func preferredInstallAssets(prefix: String, version: String) -> [UpdateInstallAsset] {
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

    func checksumAsset(for installAsset: GitHubReleaseAsset) -> GitHubReleaseAsset? {
        assets.first { $0.name == "\(installAsset.name).sha256" }
            ?? assets.first { $0.name.hasSuffix(".sha256") && $0.name.hasPrefix(installAsset.name) }
    }
}

struct GitHubReleaseAsset: Decodable {
    let name: String
    let browserDownloadURL: URL
    let digest: String?

    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadURL = "browser_download_url"
        case digest
    }
}

struct ReleaseVersion: Comparable {
    private let components: [Int]

    init(_ text: String) {
        let versionText = text.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
        let numbers = versionText
            .split { !$0.isNumber }
            .compactMap { Int($0) }
        self.components = numbers.isEmpty ? [0] : numbers
    }

    static func < (lhs: ReleaseVersion, rhs: ReleaseVersion) -> Bool {
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

enum UpdateError: LocalizedError {
    case invalidReleaseURL
    case invalidReleaseFeed
    case httpStatus(Int)
    case invalidChecksumFile
    case checksumMismatch(expected: String, actual: String)

    var errorDescription: String? {
        switch self {
        case .invalidReleaseURL:
            return "更新地址无效。"
        case .invalidReleaseFeed:
            return "没有从 GitHub Release 页面解析到最新版本。"
        case .httpStatus(let statusCode):
            return "GitHub 返回了 HTTP \(statusCode)。请稍后再试。"
        case .invalidChecksumFile:
            return "Release 里的 SHA256 校验文件格式无效，已停止安装。"
        case .checksumMismatch(let expected, let actual):
            return "下载的安装包校验失败。\n期望：\(expected)\n实际：\(actual)"
        }
    }
}

extension String {
    var shellQuoted: String {
        "'\(replacingOccurrences(of: "'", with: "'\\''"))'"
    }
}

@MainActor
final class SystemMonitor {
    var onSnapshot: ((SystemSnapshot) -> Void)?

    private let sampler = SystemSampler()
    private var timer: Timer?
    private var isRefreshing = false

    func start() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
    }

    func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true

        DispatchQueue.global(qos: .utility).async { [sampler] in
            let snapshot = sampler.sample()
            DispatchQueue.main.async { [weak self] in
                self?.onSnapshot?(snapshot)
                self?.isRefreshing = false
            }
        }
    }
}

final class StatusImageRenderer {
    private let height: CGFloat = 22
    private let temperatureFont = NSFont.monospacedDigitSystemFont(ofSize: 13.2, weight: .semibold)

    var placeholderSize: NSSize {
        NSSize(width: 38, height: height)
    }

    func image(for snapshot: SystemSnapshot, appearance: NSAppearance) -> NSImage {
        let image = NSImage(size: imageSize(for: snapshot))
        image.lockFocus()

        appearance.performAsCurrentDrawingAppearance {
            draw(snapshot, size: image.size)
        }

        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    private func imageSize(for snapshot: SystemSnapshot) -> NSSize {
        let attributes: [NSAttributedString.Key: Any] = [.font: temperatureFont]
        let textWidth = ceil(snapshot.temperatureShortText.size(withAttributes: attributes).width)
        return NSSize(width: max(38, 17 + textWidth + 1), height: height)
    }

    private func draw(_ snapshot: SystemSnapshot, size: NSSize) {
        NSColor.clear.setFill()
        NSRect(origin: .zero, size: size).fill()

        drawCombinedBars(
            memoryFraction: snapshot.memory.usedPercent / 100,
            cpuFraction: snapshot.cpuUsage / 100,
            x: 1,
            y: 4
        )
        drawTemperatureText(
            snapshot.temperatureShortText,
            temperature: snapshot.coreTemperatureC,
            x: 17
        )
    }

    private func drawCombinedBars(
        memoryFraction: Double,
        cpuFraction: Double,
        x: CGFloat,
        y: CGFloat
    ) {
        let trackRect = NSRect(x: x, y: y, width: 13, height: 14)
        let trackPath = NSBezierPath(roundedRect: trackRect, xRadius: 2.5, yRadius: 2.5)

        NSColor.separatorColor.withAlphaComponent(0.58).setStroke()
        NSColor.controlBackgroundColor.withAlphaComponent(0.4).setFill()
        trackPath.lineWidth = 1
        trackPath.fill()
        trackPath.stroke()

        let innerRect = trackRect.insetBy(dx: 1.5, dy: 1.5)
        let gap: CGFloat = 1.5
        let columnWidth = (innerRect.width - gap) / 2

        NSColor.separatorColor.withAlphaComponent(0.32).setFill()
        NSRect(
            x: innerRect.midX - 0.5,
            y: innerRect.minY + 1,
            width: 1,
            height: innerRect.height - 2
        ).fill()

        drawBarColumn(
            fraction: memoryFraction,
            color: memoryColor(memoryFraction * 100),
            rect: NSRect(x: innerRect.minX, y: innerRect.minY, width: columnWidth, height: innerRect.height)
        )
        drawBarColumn(
            fraction: cpuFraction,
            color: cpuColor(cpuFraction * 100),
            rect: NSRect(x: innerRect.minX + columnWidth + gap, y: innerRect.minY, width: columnWidth, height: innerRect.height)
        )
    }

    private func drawBarColumn(fraction: Double, color: NSColor, rect: NSRect) {
        let clamped = min(1, max(0, fraction))
        let fillHeight = max(2, rect.height * CGFloat(clamped))
        let fillRect = NSRect(x: rect.minX, y: rect.minY, width: rect.width, height: fillHeight)

        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(roundedRect: rect, xRadius: 1.5, yRadius: 1.5).addClip()
        color.setFill()
        fillRect.fill()
        NSGraphicsContext.restoreGraphicsState()
    }

    private func drawTemperatureText(_ text: String, temperature: Double?, x: CGFloat) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: temperatureFont,
            .foregroundColor: temperatureTextColor(temperature)
        ]
        text.draw(
            at: NSPoint(x: x, y: 3),
            withAttributes: attributes
        )
    }

    private func memoryColor(_ percent: Double) -> NSColor {
        if percent >= 92 { return .systemRed }
        if percent >= 82 { return .systemOrange }
        return .systemBlue
    }

    private func cpuColor(_ percent: Double) -> NSColor {
        if percent >= 85 { return .systemRed }
        if percent >= 55 { return .systemOrange }
        return .systemGreen
    }

    private func temperatureTextColor(_ temperature: Double?) -> NSColor {
        guard let temperature else { return .tertiaryLabelColor }
        if temperature >= 90 { return .systemRed }
        if temperature >= 75 { return .systemOrange }
        return .labelColor
    }
}

final class SystemSampler: @unchecked Sendable {
    private let shell: Shell
    private let temperatureReader: TemperatureReader
    private let fanSpeedReader: FanSpeedReader
    private var previousCPUTicks: CPUTicks?

    init() {
        let shell = Shell()
        self.shell = shell
        self.temperatureReader = TemperatureReader(shell: shell)
        self.fanSpeedReader = FanSpeedReader(shell: shell)
        self.previousCPUTicks = CPUTicks.current()
    }

    func sample() -> SystemSnapshot {
        SystemSnapshot(
            memory: readMemory(),
            cpuUsage: readCPUUsage(),
            coreTemperatureC: temperatureReader.read(),
            fan: fanSpeedReader.read(),
            thermalState: ProcessInfo.processInfo.thermalState,
            updatedAt: Date()
        )
    }

    private func readCPUUsage() -> Double {
        guard let ticks = CPUTicks.current() else { return 0 }
        defer { previousCPUTicks = ticks }
        guard let previousCPUTicks else { return 0 }

        let user = ticks.user - previousCPUTicks.user
        let system = ticks.system - previousCPUTicks.system
        let nice = ticks.nice - previousCPUTicks.nice
        let idle = ticks.idle - previousCPUTicks.idle
        let total = user + system + nice + idle
        guard total > 0 else { return 0 }

        return min(100, max(0, Double(user + system + nice) / Double(total) * 100))
    }

    private func readMemory() -> MemorySnapshot {
        let output = shell.run("/usr/bin/vm_stat", [])
        let pageSize = parsePageSize(output) ?? Double(getpagesize())
        let pages = parseVMStat(output)

        let freePages = pages["Pages free"] ?? 0
        let speculativePages = pages["Pages speculative"] ?? 0
        let inactivePages = pages["Pages inactive"] ?? 0
        let wiredPages = pages["Pages wired down"] ?? 0
        let compressedPages = pages["Pages occupied by compressor"] ?? pages["Pages compressed"] ?? 0
        let purgeablePages = pages["Pages purgeable"] ?? 0
        let activePages = pages["Pages active"] ?? 0

        let totalGB = Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824
        let freeGB = Double(freePages + speculativePages + purgeablePages) * pageSize / 1_073_741_824
        let inactiveGB = Double(inactivePages) * pageSize / 1_073_741_824
        let wiredGB = Double(wiredPages) * pageSize / 1_073_741_824
        let compressedGB = Double(compressedPages) * pageSize / 1_073_741_824
        let activeGB = Double(activePages) * pageSize / 1_073_741_824
        let availableGB = min(totalGB, max(0, freeGB + inactiveGB * 0.65))
        let usedGB = min(totalGB, max(0, totalGB - availableGB))
        let usedPercent = totalGB > 0 ? usedGB / totalGB * 100 : 0

        return MemorySnapshot(
            totalGB: totalGB,
            usedGB: usedGB,
            usedPercent: usedPercent,
            availableGB: availableGB,
            activeGB: activeGB,
            wiredGB: wiredGB,
            compressedGB: compressedGB
        )
    }

    private func parseVMStat(_ output: String) -> [String: Double] {
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

    private func parsePageSize(_ output: String) -> Double? {
        guard let range = output.range(of: "page size of ") else { return nil }
        let suffix = output[range.upperBound...]
        let number = suffix.prefix { $0.isNumber }
        return Double(number)
    }
}

struct SystemSnapshot {
    let memory: MemorySnapshot
    let cpuUsage: Double
    let coreTemperatureC: Double?
    let fan: FanSpeedSnapshot
    let thermalState: ProcessInfo.ThermalState
    let updatedAt: Date

    static var placeholder: SystemSnapshot {
        SystemSnapshot(
            memory: .empty,
            cpuUsage: 0,
            coreTemperatureC: nil,
            fan: .unknown,
            thermalState: .nominal,
            updatedAt: Date()
        )
    }

    var temperatureText: String {
        guard let coreTemperatureC else { return "--°C" }
        return "\(Int(coreTemperatureC.rounded()))°C"
    }

    var temperatureShortText: String {
        guard let coreTemperatureC else { return "--" }
        return "\(Int(coreTemperatureC.rounded()))°"
    }

    var temperatureFillFraction: Double {
        guard let coreTemperatureC else { return 0.08 }
        return min(1, max(0, (coreTemperatureC - 35) / 65))
    }

    var thermalStateText: String {
        switch thermalState {
        case .nominal:
            return "热状态正常"
        case .fair:
            return "略热"
        case .serious:
            return "偏热"
        case .critical:
            return "过热"
        @unknown default:
            return "热状态未知"
        }
    }

    var toolTipText: String {
        "内存 \(memory.usedPercent.percentText)  CPU \(cpuUsage.percentText)  核心温度 \(temperatureText)"
    }

    var summaryText: String {
        [
            "内存占用: \(memory.usedPercent.percentText) (\(memory.usedGB.gbText) / \(memory.totalGB.gbText))",
            "CPU 占用: \(cpuUsage.percentText)",
            "核心温度: \(temperatureText)",
            "风扇转速: \(fan.displayText)",
            "热状态: \(thermalStateText)",
            "更新时间: \(updatedAt.fullTimeText)"
        ].joined(separator: "\n")
    }
}

struct MemorySnapshot {
    let totalGB: Double
    let usedGB: Double
    let usedPercent: Double
    let availableGB: Double
    let activeGB: Double
    let wiredGB: Double
    let compressedGB: Double

    static let empty = MemorySnapshot(
        totalGB: 0,
        usedGB: 0,
        usedPercent: 0,
        availableGB: 0,
        activeGB: 0,
        wiredGB: 0,
        compressedGB: 0
    )

    var shortPercentText: String {
        usedPercent.shortPercentText
    }
}

struct FanSpeedSnapshot {
    let speedsRPM: [Double]
    let isFanless: Bool
    let source: String?

    static let unknown = FanSpeedSnapshot(speedsRPM: [], isFanless: false, source: nil)
    static let fanless = FanSpeedSnapshot(speedsRPM: [], isFanless: true, source: "SMC")

    var displayText: String {
        if isFanless {
            return "无风扇"
        }
        guard !speedsRPM.isEmpty else {
            return "未读取"
        }

        let values = speedsRPM
            .map { "\(Int($0.rounded())) RPM" }
            .joined(separator: " / ")
        if let source {
            return "\(values)  \(source)"
        }
        return values
    }
}

final class FanSpeedReader: @unchecked Sendable {
    private let shell: Shell
    private let smcReader: AppleSMCReader?

    init(shell: Shell) {
        self.shell = shell
        self.smcReader = AppleSMCReader()
    }

    func read() -> FanSpeedSnapshot {
        if let snapshot = readFromSMC() {
            return snapshot
        }
        if let snapshot = readFromIStats() {
            return snapshot
        }
        if let snapshot = readFromSMCCommand() {
            return snapshot
        }
        return .unknown
    }

    private func readFromSMC() -> FanSpeedSnapshot? {
        guard let smcReader else { return nil }

        if let fanCount = smcReader.readNumeric("FNum") {
            let count = Int(fanCount.rounded())
            if count == 0 {
                return .fanless
            }

            let speeds = (0..<min(count, 8)).compactMap { index in
                smcReader.readNumeric("F\(index)Ac")
            }
            if !speeds.isEmpty {
                return FanSpeedSnapshot(speedsRPM: speeds, isFanless: false, source: "SMC")
            }
        }

        let fallbackSpeeds = (0..<4).compactMap { index in
            smcReader.readNumeric("F\(index)Ac")
        }
        guard !fallbackSpeeds.isEmpty else { return nil }
        return FanSpeedSnapshot(speedsRPM: fallbackSpeeds, isFanless: false, source: "SMC")
    }

    private func readFromIStats() -> FanSpeedSnapshot? {
        guard let path = shell.which("istats") else { return nil }
        let output = shell.run(path, ["fan", "speed"])
        let speeds = Self.rpmValues(in: output)
        guard !speeds.isEmpty else { return nil }
        return FanSpeedSnapshot(speedsRPM: speeds, isFanless: false, source: "iStats")
    }

    private func readFromSMCCommand() -> FanSpeedSnapshot? {
        guard let path = shell.which("smc") else { return nil }

        if let fanCount = Self.firstReasonableNumber(in: shell.run(path, ["-k", "FNum", "-r"])) {
            let count = Int(fanCount.rounded())
            if count == 0 {
                return .fanless
            }

            let speeds = (0..<min(count, 8)).compactMap { index in
                Self.firstReasonableNumber(in: shell.run(path, ["-k", "F\(index)Ac", "-r"]))
            }
            if !speeds.isEmpty {
                return FanSpeedSnapshot(speedsRPM: speeds, isFanless: false, source: "smc")
            }
        }

        let fallbackSpeeds = (0..<4).compactMap { index in
            Self.firstReasonableNumber(in: shell.run(path, ["-k", "F\(index)Ac", "-r"]))
        }
        guard !fallbackSpeeds.isEmpty else { return nil }
        return FanSpeedSnapshot(speedsRPM: fallbackSpeeds, isFanless: false, source: "smc")
    }

    private static func rpmValues(in text: String) -> [Double] {
        let pattern = #"([0-9]+(?:\.[0-9]+)?)\s*(?:RPM|rpm)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range).compactMap { match -> Double? in
            guard let valueRange = Range(match.range(at: 1), in: text),
                  let value = Double(text[valueRange]),
                  value >= 0,
                  value <= 20_000
            else {
                return nil
            }
            return value
        }
    }

    private static func firstReasonableNumber(in text: String) -> Double? {
        let pattern = #"([0-9]+(?:\.[0-9]+)?)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range).compactMap { match -> Double? in
            guard let valueRange = Range(match.range(at: 1), in: text),
                  let value = Double(text[valueRange]),
                  value >= 0,
                  value <= 20_000
            else {
                return nil
            }
            return value
        }.last
    }
}

final class TemperatureReader: @unchecked Sendable {
    private let shell: Shell
    private let appleSiliconReader: AppleSiliconTemperatureReader
    private let command: TemperatureCommand?

    init(shell: Shell) {
        self.shell = shell
        self.appleSiliconReader = AppleSiliconTemperatureReader()
        self.command = TemperatureCommand.detect(shell: shell)
    }

    func read() -> Double? {
        if let temperature = appleSiliconReader.readCoreTemperature() {
            return temperature
        }

        guard let command else { return nil }

        switch command {
        case .osxCPUTemp(let path):
            return Self.lastReasonableNumber(in: shell.run(path, []))
        case .istats(let path):
            return Self.lastReasonableNumber(in: shell.run(path, ["cpu", "temp"]))
        case .smc(let path):
            return Self.lastReasonableNumber(in: shell.run(path, ["-k", "TC0P", "-r"]))
        }
    }

    private static func lastReasonableNumber(in text: String) -> Double? {
        let pattern = #"([0-9]+(?:\.[0-9]+)?)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }

        let range = NSRange(text.startIndex..., in: text)
        let values = regex
            .matches(in: text, range: range)
            .compactMap { match -> Double? in
                guard let valueRange = Range(match.range(at: 1), in: text) else { return nil }
                return Double(text[valueRange])
            }

        return values.reversed().first { $0 >= 10 && $0 <= 130 }
    }
}

private typealias HIDClient = CFTypeRef
private typealias HIDService = CFTypeRef

@_silgen_name("IOHIDEventSystemClientCreate")
private func IOHIDEventSystemClientCreate(_ allocator: CFAllocator?) -> Unmanaged<CFTypeRef>?

@_silgen_name("IOHIDEventSystemClientSetMatching")
private func IOHIDEventSystemClientSetMatching(_ client: HIDClient, _ matching: CFDictionary?)

@_silgen_name("IOHIDEventSystemClientCopyServices")
private func IOHIDEventSystemClientCopyServices(_ client: HIDClient) -> Unmanaged<CFArray>?

@_silgen_name("IOHIDServiceClientCopyProperty")
private func IOHIDServiceClientCopyProperty(_ service: HIDService, _ key: CFString) -> Unmanaged<CFTypeRef>?

@_silgen_name("IOHIDServiceClientCopyEvent")
private func IOHIDServiceClientCopyEvent(_ service: HIDService, _ type: Int64, _ options: Int32, _ timeout: Int64) -> Unmanaged<CFTypeRef>?

@_silgen_name("IOHIDEventGetFloatValue")
private func IOHIDEventGetFloatValue(_ event: CFTypeRef, _ field: Int32) -> Double

final class AppleSiliconTemperatureReader: @unchecked Sendable {
    private let temperatureEventType: Int64 = 15
    private let temperatureEventField: Int32 = 15 << 16
    private let client: HIDClient?

    init() {
        client = IOHIDEventSystemClientCreate(kCFAllocatorDefault)?.takeRetainedValue()

        if let client {
            let matching: CFDictionary = [
                "PrimaryUsagePage" as CFString: 0xFF00 as CFNumber,
                "PrimaryUsage" as CFString: 5 as CFNumber
            ] as CFDictionary
            IOHIDEventSystemClientSetMatching(client, matching)
        }
    }

    func readCoreTemperature() -> Double? {
        guard let client,
              let services = IOHIDEventSystemClientCopyServices(client)?.takeRetainedValue()
        else {
            return nil
        }

        var temperatures: [Double] = []

        for index in 0..<CFArrayGetCount(services) {
            let service = unsafeBitCast(CFArrayGetValueAtIndex(services, index), to: HIDService.self)
            let product = IOHIDServiceClientCopyProperty(service, "Product" as CFString)?
                .takeRetainedValue() as? String ?? ""

            guard product.localizedCaseInsensitiveContains("tdie"),
                  let event = IOHIDServiceClientCopyEvent(service, temperatureEventType, 0, 0)?.takeRetainedValue()
            else {
                continue
            }

            let value = IOHIDEventGetFloatValue(event, temperatureEventField)
            if value >= 10, value <= 130 {
                temperatures.append(value)
            }
        }

        return temperatures.max()
    }
}

struct SMCKeyDataVers {
    var major: UInt8 = 0
    var minor: UInt8 = 0
    var build: UInt8 = 0
    var reserved: UInt8 = 0
    var release: UInt16 = 0
}

struct SMCKeyDataPLimitData {
    var version: UInt16 = 0
    var length: UInt16 = 0
    var cpuPLimit: UInt32 = 0
    var gpuPLimit: UInt32 = 0
    var memPLimit: UInt32 = 0
}

struct SMCKeyDataKeyInfo {
    var dataSize: UInt32 = 0
    var dataType: UInt32 = 0
    var dataAttributes: UInt8 = 0
}

struct SMCKeyData {
    var key: UInt32 = 0
    var vers = SMCKeyDataVers()
    var pLimitData = SMCKeyDataPLimitData()
    var keyInfo = SMCKeyDataKeyInfo()
    var padding: UInt16 = 0
    var result: UInt8 = 0
    var status: UInt8 = 0
    var data8: UInt8 = 0
    var data32: UInt32 = 0
    var bytes: (
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8
    ) = (
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    )
}

struct SMCValue {
    let type: String
    let bytes: [UInt8]
}

final class AppleSMCReader: @unchecked Sendable {
    private let smcHandleYPCEvent: UInt32 = 2
    private let smcCmdReadBytes: UInt8 = 5
    private let smcCmdReadKeyInfo: UInt8 = 9
    private var connection: io_connect_t = 0

    init?() {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }

        guard IOServiceOpen(service, mach_task_self_, 0, &connection) == KERN_SUCCESS else {
            return nil
        }
    }

    deinit {
        if connection != 0 {
            IOServiceClose(connection)
        }
    }

    func readNumeric(_ key: String) -> Double? {
        guard let value = read(key) else { return nil }
        return decodeNumeric(value)
    }

    private func read(_ key: String) -> SMCValue? {
        var input = SMCKeyData()
        var output = SMCKeyData()
        input.key = Self.fourCC(key)
        input.data8 = smcCmdReadKeyInfo

        guard call(input: &input, output: &output) == KERN_SUCCESS,
              output.result == 0
        else {
            return nil
        }

        let keyInfo = output.keyInfo
        input.keyInfo = keyInfo
        input.data8 = smcCmdReadBytes
        output = SMCKeyData()

        guard call(input: &input, output: &output) == KERN_SUCCESS,
              output.result == 0
        else {
            return nil
        }

        let size = min(Int(keyInfo.dataSize), 32)
        let bytes = withUnsafeBytes(of: output.bytes) { rawBuffer in
            Array(rawBuffer.prefix(size))
        }

        return SMCValue(
            type: Self.fourCCString(keyInfo.dataType),
            bytes: bytes
        )
    }

    private func call(input: inout SMCKeyData, output: inout SMCKeyData) -> kern_return_t {
        let inputSize = MemoryLayout<SMCKeyData>.stride
        var outputSize = MemoryLayout<SMCKeyData>.stride
        return IOConnectCallStructMethod(
            connection,
            smcHandleYPCEvent,
            &input,
            inputSize,
            &output,
            &outputSize
        )
    }

    private func decodeNumeric(_ value: SMCValue) -> Double? {
        let bytes = value.bytes

        switch value.type {
        case "fpe2":
            guard bytes.count >= 2 else { return nil }
            let raw = (UInt16(bytes[0]) << 8) | UInt16(bytes[1])
            return Double(raw) / 4.0
        case "flt ":
            guard bytes.count >= 4 else { return nil }
            return bytes.withUnsafeBytes { rawBuffer in
                Double(rawBuffer.loadUnaligned(as: Float.self))
            }
        case "ui8 ":
            return bytes.first.map(Double.init)
        case "ui16":
            guard bytes.count >= 2 else { return nil }
            return Double((UInt16(bytes[0]) << 8) | UInt16(bytes[1]))
        case "ui32":
            guard bytes.count >= 4 else { return nil }
            return Double((UInt32(bytes[0]) << 24) |
                (UInt32(bytes[1]) << 16) |
                (UInt32(bytes[2]) << 8) |
                UInt32(bytes[3]))
        default:
            return nil
        }
    }

    private static func fourCC(_ string: String) -> UInt32 {
        var result: UInt32 = 0
        for byte in string.utf8.prefix(4) {
            result = (result << 8) + UInt32(byte)
        }
        return result
    }

    private static func fourCCString(_ value: UInt32) -> String {
        let bytes = [
            UInt8((value >> 24) & 0xff),
            UInt8((value >> 16) & 0xff),
            UInt8((value >> 8) & 0xff),
            UInt8(value & 0xff)
        ].filter { $0 != 0 }
        return String(bytes: bytes, encoding: .ascii) ?? "????"
    }
}

enum TemperatureCommand {
    case osxCPUTemp(String)
    case istats(String)
    case smc(String)

    static func detect(shell: Shell) -> TemperatureCommand? {
        if let path = shell.which("osx-cpu-temp") {
            return .osxCPUTemp(path)
        }
        if let path = shell.which("istats") {
            return .istats(path)
        }
        if let path = shell.which("smc") {
            return .smc(path)
        }
        return nil
    }
}

struct CPUTicks {
    let user: UInt64
    let nice: UInt64
    let system: UInt64
    let idle: UInt64

    static func current() -> CPUTicks? {
        var cpuInfo = host_cpu_load_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &cpuInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }

        return CPUTicks(
            user: UInt64(cpuInfo.cpu_ticks.0),
            nice: UInt64(cpuInfo.cpu_ticks.3),
            system: UInt64(cpuInfo.cpu_ticks.1),
            idle: UInt64(cpuInfo.cpu_ticks.2)
        )
    }
}

final class Shell: @unchecked Sendable {
    func run(_ executable: String, _ arguments: [String]) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        let output = Pipe()
        let error = Pipe()
        process.standardOutput = output
        process.standardError = error

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return ""
        }

        let data = output.fileHandleForReading.readDataToEndOfFile()
        if data.isEmpty {
            return String(data: error.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        }
        return String(data: data, encoding: .utf8) ?? ""
    }

    func which(_ command: String) -> String? {
        let output = run("/usr/bin/which", [command])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return output.isEmpty ? nil : output
    }
}

extension Date {
    var timeText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: self)
    }

    var fullTimeText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: self)
    }
}

extension Double {
    var percentText: String {
        "\(Int(self.rounded()))%"
    }

    var shortPercentText: String {
        "\(Int(self.rounded()))%"
    }

    var gbText: String {
        if self >= 100 {
            return "\(Int(self.rounded())) GB"
        }
        return String(format: "%.1f GB", self)
    }
}
