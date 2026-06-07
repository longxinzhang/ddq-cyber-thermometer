import AppKit
import MacHealthGuardianCore

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
