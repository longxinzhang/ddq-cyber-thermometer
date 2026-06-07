import AppKit
import Foundation

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write(Data("Usage: generate-icon.swift <output.iconset>\n".utf8))
    exit(64)
}

let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let fileManager = FileManager.default
try? fileManager.removeItem(at: outputURL)
try fileManager.createDirectory(at: outputURL, withIntermediateDirectories: true)

let variants: [(name: String, pixels: Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for variant in variants {
    let data = renderIcon(pixelSize: variant.pixels)
    try data.write(to: outputURL.appendingPathComponent(variant.name))
}

func renderIcon(pixelSize: Int) -> Data {
    let size = CGFloat(pixelSize)
    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    let image = NSImage(size: rect.size)

    image.lockFocus()
    NSGraphicsContext.current?.imageInterpolation = .high

    let backgroundPath = NSBezierPath(
        roundedRect: rect.insetBy(dx: size * 0.055, dy: size * 0.055),
        xRadius: size * 0.22,
        yRadius: size * 0.22
    )
    NSGradient(colors: [
        NSColor(calibratedRed: 0.08, green: 0.16, blue: 0.18, alpha: 1),
        NSColor(calibratedRed: 0.07, green: 0.44, blue: 0.48, alpha: 1)
    ])?.draw(in: backgroundPath, angle: -35)

    drawThermometer(size: size)
    drawBars(size: size)
    drawBadge(size: size)

    image.unlockFocus()

    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:])
    else {
        fatalError("Failed to render icon")
    }

    return png
}

func drawThermometer(size: CGFloat) {
    let stem = NSRect(x: size * 0.44, y: size * 0.26, width: size * 0.13, height: size * 0.46)
    let stemPath = NSBezierPath(roundedRect: stem, xRadius: size * 0.055, yRadius: size * 0.055)
    NSColor.white.withAlphaComponent(0.24).setStroke()
    stemPath.lineWidth = max(1, size * 0.018)
    stemPath.stroke()

    let fill = NSRect(x: stem.minX + size * 0.027, y: stem.minY + size * 0.032, width: stem.width - size * 0.054, height: stem.height * 0.62)
    NSColor.systemCyan.setFill()
    NSBezierPath(roundedRect: fill, xRadius: size * 0.025, yRadius: size * 0.025).fill()

    let bulb = NSRect(x: size * 0.395, y: size * 0.16, width: size * 0.22, height: size * 0.22)
    NSGradient(colors: [.systemCyan, .systemBlue])?.draw(
        in: NSBezierPath(ovalIn: bulb),
        angle: 90
    )
}

func drawBars(size: CGFloat) {
    let barWidth = max(2, size * 0.035)
    let gap = size * 0.025
    let bottom = size * 0.2
    let leftX = size * 0.22
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

func drawBadge(size: CGFloat) {
    guard size >= 128 else { return }

    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size * 0.15, weight: .bold),
        .foregroundColor: NSColor.white.withAlphaComponent(0.94)
    ]
    "DDQ".draw(
        in: NSRect(x: size * 0.22, y: size * 0.72, width: size * 0.56, height: size * 0.18),
        withAttributes: attributes
    )
}
