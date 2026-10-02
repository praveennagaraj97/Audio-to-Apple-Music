import AppKit
import Foundation

let output = CommandLine.arguments[1]
let fileManager = FileManager.default
let iconset = URL(fileURLWithPath: output, isDirectory: true)
try fileManager.createDirectory(at: iconset, withIntermediateDirectories: true)

func render(_ pixels: Int) throws -> Data {
    let dimension = CGFloat(pixels)
    guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                                       bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                       isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
          let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
        throw NSError(domain: "AppIcon", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not create the app icon bitmap."])
    }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    defer { NSGraphicsContext.restoreGraphicsState() }

    let rect = NSRect(x: 0, y: 0, width: dimension, height: dimension)
    NSGradient(colors: [NSColor(calibratedRed: 0.16, green: 0.28, blue: 0.76, alpha: 1),
                        NSColor(calibratedRed: 0.50, green: 0.22, blue: 0.78, alpha: 1)])!
        .draw(in: rect, angle: 135)

    let scale = dimension / 1024
    func p(_ value: CGFloat) -> CGFloat { value * scale }

    // A clear eighth note with a warm accent arrow suggesting transfer into a library.
    NSColor.white.setFill()
    let head = NSBezierPath(ovalIn: NSRect(x: p(285), y: p(220), width: p(245), height: p(155)))
    head.fill()

    let stem = NSBezierPath(roundedRect: NSRect(x: p(480), y: p(330), width: p(58), height: p(400)), xRadius: p(28), yRadius: p(28))
    stem.fill()

    let flag = NSBezierPath()
    flag.move(to: NSPoint(x: p(508), y: p(728)))
    flag.curve(to: NSPoint(x: p(775), y: p(595)), controlPoint1: NSPoint(x: p(735), y: p(735)), controlPoint2: NSPoint(x: p(785), y: p(670)))
    flag.curve(to: NSPoint(x: p(588), y: p(505)), controlPoint1: NSPoint(x: p(802), y: p(552)), controlPoint2: NSPoint(x: p(687), y: p(500)))
    flag.line(to: NSPoint(x: p(588), y: p(590)))
    flag.curve(to: NSPoint(x: p(694), y: p(648)), controlPoint1: NSPoint(x: p(657), y: p(573)), controlPoint2: NSPoint(x: p(708), y: p(606)))
    flag.curve(to: NSPoint(x: p(508), y: p(728)), controlPoint1: NSPoint(x: p(678), y: p(690)), controlPoint2: NSPoint(x: p(582), y: p(716)))
    flag.close()
    flag.fill()

    NSColor(calibratedRed: 1, green: 0.77, blue: 0.30, alpha: 1).setFill()
    let arrowHead = NSBezierPath()
    arrowHead.move(to: NSPoint(x: p(760), y: p(330)))
    arrowHead.line(to: NSPoint(x: p(850), y: p(330)))
    arrowHead.line(to: NSPoint(x: p(805), y: p(270)))
    arrowHead.close()
    arrowHead.fill()
    let arrowStem = NSBezierPath(roundedRect: NSRect(x: p(787), y: p(330), width: p(36), height: p(170)), xRadius: p(18), yRadius: p(18))
    arrowStem.fill()

    context.flushGraphics()
    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "AppIcon", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not render app icon."])
    }
    return png
}

let variants: [(String, Int)] = [
    ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024)
]
for (name, size) in variants {
    try render(size).write(to: iconset.appending(path: name), options: .atomic)
}
