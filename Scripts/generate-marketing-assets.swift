import AppKit
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let assetsURL = root.appendingPathComponent("docs/assets", isDirectory: true)
let appIconSourceURL = root.appendingPathComponent("icon.png")
try FileManager.default.createDirectory(at: assetsURL, withIntermediateDirectories: true)

try renderAppIcon(size: 512)
    .write(to: assetsURL.appendingPathComponent("app-icon.png"))
try renderHero(size: NSSize(width: 1600, height: 980))
    .write(to: assetsURL.appendingPathComponent("hero-preview.png"))
try renderWidgetCloseup(size: NSSize(width: 1200, height: 520))
    .write(to: assetsURL.appendingPathComponent("widget-closeup.png"))

func renderAppIcon(size: CGFloat) -> Data {
    guard let sourceImage = NSImage(contentsOf: appIconSourceURL) else {
        fatalError("Missing app icon source: \(appIconSourceURL.path)")
    }

    return pngData(size: NSSize(width: size, height: size)) { rect in
        NSColor.clear.setFill()
        rect.fill()

        let sourceSize = sourceImage.size
        let scale = min(rect.width / sourceSize.width, rect.height / sourceSize.height)
        let drawSize = NSSize(width: sourceSize.width * scale, height: sourceSize.height * scale)
        let drawRect = NSRect(
            x: rect.midX - drawSize.width / 2,
            y: rect.midY - drawSize.height / 2,
            width: drawSize.width,
            height: drawSize.height
        )
        sourceImage.draw(
            in: drawRect,
            from: NSRect(origin: .zero, size: sourceImage.size),
            operation: .sourceOver,
            fraction: 1
        )
    }
}

func renderHero(size: NSSize) -> Data {
    pngData(size: size) { rect in
        NSColor(calibratedRed: 0.06, green: 0.07, blue: 0.075, alpha: 1).setFill()
        rect.fill()

        drawDesktopPanel(in: NSRect(x: 650, y: 172, width: 760, height: 570))
        drawMenuBar(in: NSRect(x: 705, y: 632, width: 650, height: 52), widgetScale: 1.35)
        drawLargeWidget(in: NSRect(x: 775, y: 330, width: 510, height: 170))
        drawTinyReadouts(in: NSRect(x: 804, y: 224, width: 450, height: 70))

        let iconRect = NSRect(x: 190, y: 472, width: 170, height: 170)
        if let iconImage = NSImage(data: renderAppIcon(size: 512)) {
            iconImage.draw(in: iconRect)
        }

        drawText(
            "DDQ's Cyber Thermometer",
            in: NSRect(x: 180, y: 392, width: 680, height: 58),
            font: .systemFont(ofSize: 40, weight: .bold),
            color: .white
        )
        drawText(
            "动动枪赛博体温计",
            in: NSRect(x: 184, y: 342, width: 560, height: 42),
            font: .systemFont(ofSize: 30, weight: .semibold),
            color: NSColor.white.withAlphaComponent(0.9)
        )
        drawText(
            "一个安静待在 macOS 顶栏里的电脑状态小组件。",
            in: NSRect(x: 184, y: 304, width: 560, height: 34),
            font: .systemFont(ofSize: 23, weight: .medium),
            color: NSColor.white.withAlphaComponent(0.78)
        )
        drawText(
            "内存、CPU、核心温度，一眼看完。",
            in: NSRect(x: 184, y: 260, width: 520, height: 32),
            font: .systemFont(ofSize: 22, weight: .regular),
            color: NSColor(calibratedRed: 0.68, green: 0.93, blue: 0.9, alpha: 1)
        )

        drawDownloadPill(in: NSRect(x: 184, y: 188, width: 230, height: 52))
    }
}

func renderWidgetCloseup(size: NSSize) -> Data {
    pngData(size: size) { rect in
        NSGradient(colors: [
            NSColor(calibratedRed: 0.15, green: 0.13, blue: 0.12, alpha: 1),
            NSColor(calibratedRed: 0.42, green: 0.33, blue: 0.15, alpha: 1),
            NSColor(calibratedRed: 0.05, green: 0.12, blue: 0.13, alpha: 1)
        ])?.draw(in: rect, angle: 18)

        drawMenuBar(in: NSRect(x: 105, y: 335, width: 990, height: 72), widgetScale: 1.85)
        drawLargeWidget(in: NSRect(x: 312, y: 126, width: 575, height: 150))
        drawText(
            "左柱内存 · 右柱 CPU · 温度紧贴显示",
            in: NSRect(x: 260, y: 58, width: 680, height: 42),
            font: .systemFont(ofSize: 29, weight: .semibold),
            color: .white
        )
    }
}

func drawDesktopPanel(in rect: NSRect) {
    let path = NSBezierPath(roundedRect: rect, xRadius: 24, yRadius: 24)
    NSGradient(colors: [
        NSColor(calibratedRed: 0.15, green: 0.18, blue: 0.18, alpha: 1),
        NSColor(calibratedRed: 0.08, green: 0.11, blue: 0.12, alpha: 1)
    ])?.draw(in: path, angle: -90)
    NSColor.white.withAlphaComponent(0.12).setStroke()
    path.lineWidth = 2
    path.stroke()
}

func drawMenuBar(in rect: NSRect, widgetScale: CGFloat) {
    let path = NSBezierPath(roundedRect: rect, xRadius: 10, yRadius: 10)
    NSColor.black.withAlphaComponent(0.78).setFill()
    path.fill()
    NSColor.white.withAlphaComponent(0.14).setStroke()
    path.lineWidth = 1
    path.stroke()

    drawText("Finder", in: NSRect(x: rect.minX + 24, y: rect.minY + rect.height * 0.31, width: 120, height: 24), font: .systemFont(ofSize: rect.height * 0.28, weight: .semibold), color: .white)
    drawText("Wi-Fi", in: NSRect(x: rect.maxX - 210, y: rect.minY + rect.height * 0.31, width: 60, height: 24), font: .systemFont(ofSize: rect.height * 0.25, weight: .medium), color: NSColor.white.withAlphaComponent(0.74))
    drawText("12:40", in: NSRect(x: rect.maxX - 112, y: rect.minY + rect.height * 0.31, width: 70, height: 24), font: .monospacedDigitSystemFont(ofSize: rect.height * 0.25, weight: .medium), color: NSColor.white.withAlphaComponent(0.82))

    let widgetWidth = 86 * widgetScale
    let widgetRect = NSRect(x: rect.maxX - 365, y: rect.midY - 12 * widgetScale, width: widgetWidth, height: 24 * widgetScale)
    drawCompactWidget(in: widgetRect, temperature: "43°", scale: widgetScale)
}

func drawLargeWidget(in rect: NSRect) {
    let path = NSBezierPath(roundedRect: rect, xRadius: 18, yRadius: 18)
    NSColor.black.withAlphaComponent(0.48).setFill()
    path.fill()
    NSColor.white.withAlphaComponent(0.16).setStroke()
    path.lineWidth = 1.4
    path.stroke()

    drawCompactWidget(in: NSRect(x: rect.minX + 52, y: rect.midY - 42, width: 264, height: 84), temperature: "43°", scale: 3.35)
    drawText("悬停显示完整数值", in: NSRect(x: rect.minX + 322, y: rect.midY + 8, width: 210, height: 34), font: .systemFont(ofSize: 24, weight: .bold), color: .white)
    drawText("内存 79% · CPU 15% · 温度 43°C", in: NSRect(x: rect.minX + 323, y: rect.midY - 30, width: 295, height: 28), font: .systemFont(ofSize: 17, weight: .medium), color: NSColor.white.withAlphaComponent(0.72))
}

func drawTinyReadouts(in rect: NSRect) {
    let items = [("79%", "内存"), ("15%", "CPU"), ("43°C", "核心")]
    let width = rect.width / CGFloat(items.count)
    for (index, item) in items.enumerated() {
        let itemRect = NSRect(x: rect.minX + CGFloat(index) * width, y: rect.minY, width: width - 14, height: rect.height)
        let path = NSBezierPath(roundedRect: itemRect, xRadius: 8, yRadius: 8)
        NSColor.white.withAlphaComponent(0.07).setFill()
        path.fill()
        drawText(item.0, in: NSRect(x: itemRect.minX + 16, y: itemRect.minY + 27, width: itemRect.width - 32, height: 28), font: .monospacedDigitSystemFont(ofSize: 22, weight: .bold), color: .white)
        drawText(item.1, in: NSRect(x: itemRect.minX + 16, y: itemRect.minY + 10, width: itemRect.width - 32, height: 18), font: .systemFont(ofSize: 13, weight: .medium), color: NSColor.white.withAlphaComponent(0.56))
    }
}

func drawCompactWidget(in rect: NSRect, temperature: String, scale: CGFloat) {
    let trackRect = NSRect(x: rect.minX, y: rect.midY - 7 * scale, width: 13 * scale, height: 14 * scale)
    let trackPath = NSBezierPath(roundedRect: trackRect, xRadius: 2.5 * scale, yRadius: 2.5 * scale)
    NSColor.white.withAlphaComponent(0.16).setFill()
    NSColor.white.withAlphaComponent(0.33).setStroke()
    trackPath.lineWidth = max(1, scale * 0.72)
    trackPath.fill()
    trackPath.stroke()

    let inner = trackRect.insetBy(dx: 1.5 * scale, dy: 1.5 * scale)
    let gap = 1.5 * scale
    let columnWidth = (inner.width - gap) / 2
    drawColumn(NSRect(x: inner.minX, y: inner.minY, width: columnWidth, height: inner.height), fraction: 0.79, color: .systemBlue)
    drawColumn(NSRect(x: inner.minX + columnWidth + gap, y: inner.minY, width: columnWidth, height: inner.height), fraction: 0.15, color: .systemGreen)

    let temperatureFont = NSFont.monospacedDigitSystemFont(ofSize: 13.2 * scale, weight: .semibold)
    let networkFont = NSFont.monospacedDigitSystemFont(ofSize: 8.8 * scale, weight: .semibold)
    let temperatureX = trackRect.maxX + 3 * scale
    let temperatureWidth = ceil(temperature.size(withAttributes: [.font: temperatureFont]).width)
    drawText(
        temperature,
        in: NSRect(x: temperatureX, y: rect.midY - 9.5 * scale, width: temperatureWidth + 2 * scale, height: 22 * scale),
        font: temperatureFont,
        color: .white
    )

    let networkX = temperatureX + temperatureWidth + 4 * scale
    drawText(
        "↓6KB",
        in: NSRect(x: networkX, y: rect.midY + 0.4 * scale, width: rect.maxX - networkX, height: 10 * scale),
        font: networkFont,
        color: .white
    )
    drawText(
        "↑4KB",
        in: NSRect(x: networkX, y: rect.midY - 8.3 * scale, width: rect.maxX - networkX, height: 10 * scale),
        font: networkFont,
        color: .white
    )
}

func drawColumn(_ rect: NSRect, fraction: CGFloat, color: NSColor) {
    let fillHeight = max(2, rect.height * fraction)
    let fill = NSRect(x: rect.minX, y: rect.minY, width: rect.width, height: fillHeight)
    NSGraphicsContext.saveGraphicsState()
    NSBezierPath(roundedRect: rect, xRadius: 1.5, yRadius: 1.5).addClip()
    color.setFill()
    fill.fill()
    NSGraphicsContext.restoreGraphicsState()
}

func drawDownloadPill(in rect: NSRect) {
    let path = NSBezierPath(roundedRect: rect, xRadius: 8, yRadius: 8)
    NSColor(calibratedRed: 0.68, green: 0.93, blue: 0.9, alpha: 1).setFill()
    path.fill()
    drawText("下载 v0.8.1", in: NSRect(x: rect.minX + 30, y: rect.minY + 14, width: rect.width - 60, height: 24), font: .systemFont(ofSize: 20, weight: .bold), color: NSColor(calibratedRed: 0.04, green: 0.1, blue: 0.1, alpha: 1))
}

func drawThermometer(size: CGFloat, origin: CGPoint) {
    let stem = NSRect(x: origin.x + size * 0.44, y: origin.y + size * 0.26, width: size * 0.13, height: size * 0.46)
    let stemPath = NSBezierPath(roundedRect: stem, xRadius: size * 0.055, yRadius: size * 0.055)
    NSColor.white.withAlphaComponent(0.24).setStroke()
    stemPath.lineWidth = max(1, size * 0.018)
    stemPath.stroke()

    let fill = NSRect(x: stem.minX + size * 0.027, y: stem.minY + size * 0.032, width: stem.width - size * 0.054, height: stem.height * 0.62)
    NSColor.systemCyan.setFill()
    NSBezierPath(roundedRect: fill, xRadius: size * 0.025, yRadius: size * 0.025).fill()

    let bulb = NSRect(x: origin.x + size * 0.395, y: origin.y + size * 0.16, width: size * 0.22, height: size * 0.22)
    NSGradient(colors: [.systemCyan, .systemBlue])?.draw(in: NSBezierPath(ovalIn: bulb), angle: 90)
}

func drawBars(size: CGFloat, origin: CGPoint) {
    let barWidth = max(2, size * 0.035)
    let gap = size * 0.025
    let bottom = origin.y + size * 0.2
    let leftX = origin.x + size * 0.22
    let heights = [size * 0.28, size * 0.43]

    for (index, height) in heights.enumerated() {
        let rect = NSRect(
            x: leftX + CGFloat(index) * (barWidth + gap),
            y: bottom,
            width: barWidth,
            height: height
        )
        NSColor.white.withAlphaComponent(index == 0 ? 0.92 : 0.62).setFill()
        NSBezierPath(roundedRect: rect, xRadius: barWidth * 0.5, yRadius: barWidth * 0.5).fill()
    }
}

func drawBadge(size: CGFloat, origin: CGPoint) {
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size * 0.15, weight: .bold),
        .foregroundColor: NSColor.white.withAlphaComponent(0.94)
    ]
    "DDQ".draw(
        in: NSRect(x: origin.x + size * 0.22, y: origin.y + size * 0.72, width: size * 0.56, height: size * 0.18),
        withAttributes: attributes
    )
}

func drawText(_ text: String, in rect: NSRect, font: NSFont, color: NSColor) {
    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.lineBreakMode = .byTruncatingTail
    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: color,
        .paragraphStyle: paragraphStyle
    ]
    text.draw(in: rect, withAttributes: attributes)
}

func pngData(size: NSSize, draw: (NSRect) -> Void) -> Data {
    let image = NSImage(size: size)
    image.lockFocus()
    NSGraphicsContext.current?.imageInterpolation = .high
    draw(NSRect(origin: .zero, size: size))
    image.unlockFocus()

    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:])
    else {
        fatalError("Failed to render image")
    }

    return png
}
