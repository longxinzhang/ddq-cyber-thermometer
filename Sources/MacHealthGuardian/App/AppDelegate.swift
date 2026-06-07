import AppKit
import MacHealthGuardianCore

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
