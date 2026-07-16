import AppKit
import MacHealthGuardianCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let monitor = SystemMonitor()
    private let renderer = StatusImageRenderer()
    private let updateController = UpdateController()
    private let launchAtLoginController = LaunchAtLoginController()
    private let displaySettings = MenuBarDisplaySettings()
    private let quickLinkSettings = QuickLinkSettings()
    private let menu = NSMenu()
    private var quickLinkItems: [NSMenuItem] = []
    private let manageQuickLinksItem = NSMenuItem(title: "管理快捷入口…", action: nil, keyEquivalent: "")
    private let memoryPressureItem = NSMenuItem(title: "内存压力 --", action: nil, keyEquivalent: "")
    private let calendarMenuView = MonthCalendarMenuView()
    private let calendarItem = NSMenuItem()
    private let memoryItem = NSMenuItem(title: "内存 --", action: nil, keyEquivalent: "")
    private let networkItem = NSMenuItem(title: "网络流量 --", action: nil, keyEquivalent: "")
    private let cpuItem = NSMenuItem(title: "CPU --", action: nil, keyEquivalent: "")
    private let temperatureItem = NSMenuItem(title: "核心温度 --", action: nil, keyEquivalent: "")
    private let fanItem = NSMenuItem(title: "风扇转速 --", action: nil, keyEquivalent: "")
    private let updatedItem = NSMenuItem(title: "等待刷新", action: nil, keyEquivalent: "")
    private let displayHeaderItem = NSMenuItem(title: "菜单栏显示", action: nil, keyEquivalent: "")
    private let memoryPressureDisplayItem = NSMenuItem(title: MenuBarDisplayMetric.memoryPressure.title, action: nil, keyEquivalent: "")
    private let memoryUsageDisplayItem = NSMenuItem(title: MenuBarDisplayMetric.memoryUsage.title, action: nil, keyEquivalent: "")
    private let cpuUsageDisplayItem = NSMenuItem(title: MenuBarDisplayMetric.cpuUsage.title, action: nil, keyEquivalent: "")
    private let versionItem = NSMenuItem(title: AppVersion.menuTitle, action: nil, keyEquivalent: "")
    private let launchAtLoginItem = NSMenuItem(title: "开机启动", action: nil, keyEquivalent: "")
    private let updateItem = NSMenuItem(title: "检查更新…", action: nil, keyEquivalent: "")
    private let copyDiagnosticsItem = NSMenuItem(title: "复制诊断信息", action: nil, keyEquivalent: "")
    private var statusItem: NSStatusItem?
    private var latestSnapshot = SystemSnapshot.placeholder

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
                displayMetrics: displaySettings.metrics,
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

        configureQuickLinkMenuItems()
        menu.addItem(.separator())

        [memoryPressureItem, memoryItem, networkItem, cpuItem, temperatureItem, fanItem, updatedItem].forEach { item in
            item.isEnabled = false
        }

        menu.addItem(memoryPressureItem)
        calendarItem.view = calendarMenuView
        menu.addItem(calendarItem)
        menu.addItem(memoryItem)
        menu.addItem(networkItem)
        menu.addItem(cpuItem)
        menu.addItem(temperatureItem)
        menu.addItem(fanItem)
        menu.addItem(updatedItem)
        menu.addItem(.separator())

        displayHeaderItem.isEnabled = false
        menu.addItem(displayHeaderItem)
        configureDisplayToggle(memoryPressureDisplayItem, metric: .memoryPressure)
        configureDisplayToggle(memoryUsageDisplayItem, metric: .memoryUsage)
        configureDisplayToggle(cpuUsageDisplayItem, metric: .cpuUsage)
        menu.addItem(memoryPressureDisplayItem)
        menu.addItem(memoryUsageDisplayItem)
        menu.addItem(cpuUsageDisplayItem)
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

        copyDiagnosticsItem.action = #selector(copyDiagnosticReport)
        copyDiagnosticsItem.target = self
        menu.addItem(copyDiagnosticsItem)
        menu.addItem(.separator())

        versionItem.isEnabled = false
        menu.addItem(versionItem)

        let quitItem = NSMenuItem(
            title: "退出",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)
    }

    func menuWillOpen(_ menu: NSMenu) {
        updateQuickLinkMenuItems()
        calendarMenuView.resetToCurrentMonth()
        updateLaunchAtLoginMenuItem()
        updateDisplayMenuItems()
    }

    private func render(_ snapshot: SystemSnapshot) {
        guard let button = statusItem?.button else { return }

        latestSnapshot = snapshot
        let image = renderer.image(
            for: snapshot,
            displayMetrics: displaySettings.metrics,
            appearance: button.effectiveAppearance
        )
        statusItem?.length = image.size.width
        button.toolTip = snapshot.toolTipText
        button.image = image

        memoryPressureItem.title = "内存压力 \(snapshot.memory.pressure.level.displayText)  \(snapshot.memory.pressure.scoreText)"
        memoryItem.title = "内存占用 \(snapshot.memory.usedPercent.percentText)  \(snapshot.memory.usedGB.gbText) / \(snapshot.memory.totalGB.gbText)"
        networkItem.title = "网络流量 \(snapshot.network.displayText)"
        cpuItem.title = "CPU 占用 \(snapshot.cpuUsage.percentText)"
        temperatureItem.title = "核心温度 \(snapshot.temperatureText)  \(snapshot.thermalStateText)"
        fanItem.title = "风扇转速 \(snapshot.fan.displayText)"
        updatedItem.title = "更新 \(snapshot.updatedAt.timeText)"
    }

    @objc private func refreshNow() {
        monitor.refresh()
    }

    @objc private func copyDiagnosticReport() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(
            AppDiagnosticReport.text(snapshot: latestSnapshot),
            forType: .string
        )
    }

    @objc private func openOrEditQuickLink(_ sender: NSMenuItem) {
        guard let index = sender.representedObject as? Int else { return }

        guard let link = quickLinkSettings.link(at: index),
              let url = link.url
        else {
            editQuickLink(at: index)
            return
        }

        NSWorkspace.shared.open(url)
    }

    @objc private func manageQuickLinks() {
        let links = quickLinkSettings.links
        let popup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 280, height: 28), pullsDown: false)

        for index in 0..<QuickLinkSettings.slotCount {
            if let link = links[index] {
                popup.addItem(withTitle: "\(index + 1). \(link.title)")
            } else {
                popup.addItem(withTitle: "\(index + 1). 空入口")
            }
        }

        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "管理快捷入口"
        alert.informativeText = "选择一个位置来新增、修改或清空。"
        alert.accessoryView = popup
        alert.addButton(withTitle: "编辑")
        alert.addButton(withTitle: "取消")

        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        editQuickLink(at: popup.indexOfSelectedItem)
    }

    @objc private func toggleDisplayMetric(_ sender: NSMenuItem) {
        guard let rawMetric = sender.representedObject as? String,
              let metric = MenuBarDisplayMetric(rawValue: rawMetric)
        else {
            return
        }

        displaySettings.toggle(metric)
        updateDisplayMenuItems()
        render(latestSnapshot)
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

    private func configureDisplayToggle(_ item: NSMenuItem, metric: MenuBarDisplayMetric) {
        item.action = #selector(toggleDisplayMetric)
        item.target = self
        item.representedObject = metric.rawValue
    }

    private func configureQuickLinkMenuItems() {
        quickLinkItems = (0..<QuickLinkSettings.slotCount).map { index in
            let item = NSMenuItem(title: "", action: #selector(openOrEditQuickLink), keyEquivalent: "")
            item.target = self
            item.representedObject = index
            menu.addItem(item)
            return item
        }

        manageQuickLinksItem.action = #selector(manageQuickLinks)
        manageQuickLinksItem.target = self
        menu.addItem(manageQuickLinksItem)
        updateQuickLinkMenuItems()
    }

    private func updateDisplayMenuItems() {
        updateDisplayMenuItem(memoryPressureDisplayItem, metric: .memoryPressure)
        updateDisplayMenuItem(memoryUsageDisplayItem, metric: .memoryUsage)
        updateDisplayMenuItem(cpuUsageDisplayItem, metric: .cpuUsage)
    }

    private func updateDisplayMenuItem(_ item: NSMenuItem, metric: MenuBarDisplayMetric) {
        item.state = displaySettings.isEnabled(metric) ? .on : .off
        item.isEnabled = displaySettings.canDisable(metric)
    }

    private func updateLaunchAtLoginMenuItem() {
        launchAtLoginItem.state = launchAtLoginController.isEnabled ? .on : .off
        launchAtLoginItem.isEnabled = launchAtLoginController.canToggle
    }

    private func updateQuickLinkMenuItems() {
        let links = quickLinkSettings.links

        for (index, item) in quickLinkItems.enumerated() {
            if let link = links[index] {
                item.title = "↗ \(link.title)"
                item.toolTip = link.urlString
            } else {
                item.title = "+ 添加快捷入口 \(index + 1)…"
                item.toolTip = "设置快捷入口名称和链接地址"
            }
        }
    }

    private func editQuickLink(at index: Int) {
        guard (0..<QuickLinkSettings.slotCount).contains(index) else { return }

        let existing = quickLinkSettings.link(at: index)
        let titleField = NSTextField(string: existing?.title ?? "")
        let urlField = NSTextField(string: existing?.urlString ?? "")
        titleField.placeholderString = "例如：雪鸡号池用量"
        urlField.placeholderString = "https://example.com/"

        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "快捷入口 \(index + 1)"
        alert.informativeText = "填写功能名称和网页链接。没有 http:// 或 https:// 时会自动按 https:// 保存。"
        alert.accessoryView = quickLinkEditorView(titleField: titleField, urlField: urlField)
        alert.addButton(withTitle: "保存")
        alert.addButton(withTitle: "取消")

        if existing != nil {
            alert.addButton(withTitle: "清空")
        }

        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()

        switch response {
        case .alertFirstButtonReturn:
            guard let link = QuickLink(title: titleField.stringValue, rawURLString: urlField.stringValue) else {
                showQuickLinkValidationError()
                editQuickLink(at: index)
                return
            }

            quickLinkSettings.setLink(link, at: index)
            updateQuickLinkMenuItems()
        case .alertThirdButtonReturn:
            quickLinkSettings.setLink(nil, at: index)
            updateQuickLinkMenuItems()
        default:
            break
        }
    }

    private func quickLinkEditorView(titleField: NSTextField, urlField: NSTextField) -> NSView {
        titleField.translatesAutoresizingMaskIntoConstraints = false
        urlField.translatesAutoresizingMaskIntoConstraints = false
        titleField.widthAnchor.constraint(equalToConstant: 280).isActive = true
        urlField.widthAnchor.constraint(equalToConstant: 280).isActive = true

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(labeledFieldRow(title: "名称", field: titleField))
        stack.addArrangedSubview(labeledFieldRow(title: "链接", field: urlField))

        let container = NSView(frame: NSRect(x: 0, y: 0, width: 340, height: 64))
        container.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        return container
    }

    private func labeledFieldRow(title: String, field: NSTextField) -> NSView {
        let label = NSTextField(labelWithString: title)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.alignment = .right
        label.widthAnchor.constraint(equalToConstant: 44).isActive = true

        let row = NSStackView()
        row.translatesAutoresizingMaskIntoConstraints = false
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 8
        row.addArrangedSubview(label)
        row.addArrangedSubview(field)

        return row
    }

    private func showQuickLinkValidationError() {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "快捷入口保存失败"
        alert.informativeText = "请填写名称，并使用有效的 http 或 https 链接。"
        alert.addButton(withTitle: "好")

        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
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
