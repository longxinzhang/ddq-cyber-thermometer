import AppKit
import Foundation
import MacHealthGuardianCore

@MainActor
final class UpdateInstaller {
    private let appBundleName = "动动枪赛博体温计.app"

    func startInstaller(
        package: UpdateInstallAsset,
        downloadedURL: URL,
        manualFallback: (URL) -> Void
    ) throws {
        let appURL = Bundle.main.bundleURL
        guard appURL.pathExtension == "app" else {
            manualFallback(downloadedURL)
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
}
