import AppKit
import MacHealthGuardianCore

final class StatusImageRenderer {
    private let height: CGFloat = 22
    private let temperatureFont = NSFont.monospacedDigitSystemFont(ofSize: 13.2, weight: .semibold)
    private let networkFont = NSFont.monospacedDigitSystemFont(ofSize: 10.2, weight: .medium)
    private let defaultMetrics: [MenuBarDisplayMetric] = [.memoryPressure, .memoryUsage, .cpuUsage]

    var placeholderSize: NSSize {
        NSSize(width: 43, height: height)
    }

    func image(
        for snapshot: SystemSnapshot,
        displayMetrics: [MenuBarDisplayMetric],
        appearance: NSAppearance
    ) -> NSImage {
        let metrics = normalizedMetrics(displayMetrics)
        let image = NSImage(size: imageSize(for: snapshot, displayMetrics: metrics))
        image.lockFocus()

        appearance.performAsCurrentDrawingAppearance {
            draw(snapshot, displayMetrics: metrics, size: image.size)
        }

        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    private func imageSize(for snapshot: SystemSnapshot, displayMetrics: [MenuBarDisplayMetric]) -> NSSize {
        let temperatureAttributes: [NSAttributedString.Key: Any] = [.font: temperatureFont]
        let networkAttributes: [NSAttributedString.Key: Any] = [.font: networkFont]
        let temperatureWidth = ceil(snapshot.temperatureShortText.size(withAttributes: temperatureAttributes).width)
        let networkWidth = ceil(snapshot.network.shortText.size(withAttributes: networkAttributes).width)
        let textX = textStartX(metricCount: displayMetrics.count)
        return NSSize(width: max(38, textX + temperatureWidth + 5 + networkWidth + 1), height: height)
    }

    private func draw(_ snapshot: SystemSnapshot, displayMetrics: [MenuBarDisplayMetric], size: NSSize) {
        NSColor.clear.setFill()
        NSRect(origin: .zero, size: size).fill()

        drawMetricBars(
            displayMetrics,
            snapshot: snapshot,
            x: 1,
            y: 4
        )
        let networkX = drawTemperatureText(
            snapshot.temperatureShortText,
            temperature: snapshot.coreTemperatureC,
            x: textStartX(metricCount: displayMetrics.count)
        )
        drawNetworkText(snapshot.network.shortText, x: networkX + 5)
    }

    private func drawMetricBars(
        _ metrics: [MenuBarDisplayMetric],
        snapshot: SystemSnapshot,
        x: CGFloat,
        y: CGFloat
    ) {
        let trackRect = NSRect(x: x, y: y, width: barGroupWidth(metricCount: metrics.count), height: 14)
        let trackPath = NSBezierPath(roundedRect: trackRect, xRadius: 2.5, yRadius: 2.5)

        NSColor.separatorColor.withAlphaComponent(0.58).setStroke()
        NSColor.controlBackgroundColor.withAlphaComponent(0.4).setFill()
        trackPath.lineWidth = 1
        trackPath.fill()
        trackPath.stroke()

        let innerRect = trackRect.insetBy(dx: 1.5, dy: 1.5)
        let gap: CGFloat = 1.5
        let columnWidth = (innerRect.width - gap * CGFloat(metrics.count - 1)) / CGFloat(metrics.count)

        if metrics.count > 1 {
            NSColor.separatorColor.withAlphaComponent(0.32).setFill()
            for index in 1..<metrics.count {
                let separatorX = innerRect.minX
                    + CGFloat(index) * columnWidth
                    + CGFloat(index - 1) * gap
                    + gap / 2
                    - 0.5
                NSRect(
                    x: separatorX,
                    y: innerRect.minY + 1,
                    width: 1,
                    height: innerRect.height - 2
                ).fill()
            }
        }

        for (index, metric) in metrics.enumerated() {
            let x = innerRect.minX + CGFloat(index) * (columnWidth + gap)
            drawBarColumn(
                fraction: fraction(for: metric, snapshot: snapshot),
                color: color(for: metric, snapshot: snapshot),
                rect: NSRect(x: x, y: innerRect.minY, width: columnWidth, height: innerRect.height)
            )
        }
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

    private func drawTemperatureText(_ text: String, temperature: Double?, x: CGFloat) -> CGFloat {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: temperatureFont,
            .foregroundColor: temperatureTextColor(temperature)
        ]
        text.draw(
            at: NSPoint(x: x, y: 3),
            withAttributes: attributes
        )
        return x + ceil(text.size(withAttributes: attributes).width)
    }

    private func drawNetworkText(_ text: String, x: CGFloat) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: networkFont,
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        text.draw(
            at: NSPoint(x: x, y: 4.4),
            withAttributes: attributes
        )
    }

    private func normalizedMetrics(_ metrics: [MenuBarDisplayMetric]) -> [MenuBarDisplayMetric] {
        let selected = Set(metrics)
        let normalized = MenuBarDisplayMetric.allCases.filter { selected.contains($0) }
        return normalized.isEmpty ? defaultMetrics : normalized
    }

    private func barGroupWidth(metricCount: Int) -> CGFloat {
        switch metricCount {
        case 1:
            return 10
        case 2:
            return 13
        default:
            return 18
        }
    }

    private func textStartX(metricCount: Int) -> CGFloat {
        1 + barGroupWidth(metricCount: metricCount) + 3
    }

    private func fraction(for metric: MenuBarDisplayMetric, snapshot: SystemSnapshot) -> Double {
        switch metric {
        case .memoryPressure:
            return snapshot.memory.pressure.score / 100
        case .memoryUsage:
            return snapshot.memory.usedPercent / 100
        case .cpuUsage:
            return snapshot.cpuUsage / 100
        }
    }

    private func color(for metric: MenuBarDisplayMetric, snapshot: SystemSnapshot) -> NSColor {
        switch metric {
        case .memoryPressure:
            return memoryPressureColor(snapshot.memory.pressure.level)
        case .memoryUsage:
            return memoryColor(snapshot.memory.usedPercent)
        case .cpuUsage:
            return cpuColor(snapshot.cpuUsage)
        }
    }

    private func memoryPressureColor(_ level: MemoryPressureLevel) -> NSColor {
        switch level {
        case .normal:
            return .systemGreen
        case .warning:
            return .systemOrange
        case .critical:
            return .systemRed
        }
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
