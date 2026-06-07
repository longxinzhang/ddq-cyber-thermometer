import AppKit
import Darwin
import Foundation
import IOKit
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
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let monitor = SystemMonitor()
    private let renderer = StatusImageRenderer()
    private let menu = NSMenu()
    private let memoryItem = NSMenuItem(title: "内存 --", action: nil, keyEquivalent: "")
    private let cpuItem = NSMenuItem(title: "CPU --", action: nil, keyEquivalent: "")
    private let temperatureItem = NSMenuItem(title: "核心温度 --", action: nil, keyEquivalent: "")
    private let fanItem = NSMenuItem(title: "风扇转速 --", action: nil, keyEquivalent: "")
    private let updatedItem = NSMenuItem(title: "等待刷新", action: nil, keyEquivalent: "")
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
        [memoryItem, cpuItem, temperatureItem, fanItem, updatedItem].forEach { item in
            item.isEnabled = false
        }

        menu.addItem(memoryItem)
        menu.addItem(cpuItem)
        menu.addItem(temperatureItem)
        menu.addItem(fanItem)
        menu.addItem(updatedItem)
        menu.addItem(.separator())

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

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
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

        input.keyInfo = output.keyInfo
        input.data8 = smcCmdReadBytes

        guard call(input: &input, output: &output) == KERN_SUCCESS,
              output.result == 0
        else {
            return nil
        }

        let size = min(Int(output.keyInfo.dataSize), 32)
        let bytes = withUnsafeBytes(of: output.bytes) { rawBuffer in
            Array(rawBuffer.prefix(size))
        }

        return SMCValue(
            type: Self.fourCCString(output.keyInfo.dataType),
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
            let raw = (UInt32(bytes[0]) << 24) |
                (UInt32(bytes[1]) << 16) |
                (UInt32(bytes[2]) << 8) |
                UInt32(bytes[3])
            return Double(Float(bitPattern: raw))
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
