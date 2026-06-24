import AppKit
import Foundation

guard CommandLine.arguments.count == 3 else {
    FileHandle.standardError.write(Data("Usage: generate-icon.swift <source.png> <output.iconset>\n".utf8))
    exit(64)
}

let sourceURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])
let fileManager = FileManager.default
try? fileManager.removeItem(at: outputURL)
try fileManager.createDirectory(at: outputURL, withIntermediateDirectories: true)

guard let sourceImage = NSImage(contentsOf: sourceURL),
      sourceImage.isValid,
      sourceImage.size.width > 0,
      sourceImage.size.height > 0
else {
    FileHandle.standardError.write(Data("Could not read icon source: \(sourceURL.path)\n".utf8))
    exit(66)
}

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
    let data = renderIcon(sourceImage: sourceImage, pixelSize: variant.pixels)
    try data.write(to: outputURL.appendingPathComponent(variant.name))
}

func renderIcon(sourceImage: NSImage, pixelSize: Int) -> Data {
    let size = CGFloat(pixelSize)
    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixelSize,
        pixelsHigh: pixelSize,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        fatalError("Failed to create bitmap for icon size \(pixelSize)")
    }

    bitmap.size = rect.size

    NSGraphicsContext.saveGraphicsState()
    guard let graphicsContext = NSGraphicsContext(bitmapImageRep: bitmap) else {
        fatalError("Failed to create graphics context for icon size \(pixelSize)")
    }
    NSGraphicsContext.current = graphicsContext
    graphicsContext.imageInterpolation = .high

    NSColor.clear.setFill()
    rect.fill()

    let sourceSize = sourceImage.size
    let scale = min(size / sourceSize.width, size / sourceSize.height)
    let drawSize = NSSize(width: sourceSize.width * scale, height: sourceSize.height * scale)
    let drawRect = NSRect(
        x: (size - drawSize.width) / 2,
        y: (size - drawSize.height) / 2,
        width: drawSize.width,
        height: drawSize.height
    )
    sourceImage.draw(
        in: drawRect,
        from: NSRect(origin: .zero, size: sourceImage.size),
        operation: .sourceOver,
        fraction: 1
    )

    NSGraphicsContext.restoreGraphicsState()

    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        fatalError("Failed to render icon")
    }

    return png
}
