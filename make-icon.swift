// Renders AppIcon.png (1024×1024): the Edith logo on a dark gradient squircle.
// Run via `swift make-icon.swift AppIcon.png`; build.sh turns it into the .icns.
import AppKit

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.png"
let px = 1024

let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

// macOS-style margins: the squircle fills ~81% of the canvas.
let side = CGFloat(px) * 0.8125
let origin = (CGFloat(px) - side) / 2
let squircle = NSBezierPath(
    roundedRect: NSRect(x: origin, y: origin, width: side, height: side),
    xRadius: side * 0.225, yRadius: side * 0.225
)
NSGradient(colors: [
    NSColor(calibratedRed: 0.07, green: 0.09, blue: 0.15, alpha: 1),
    NSColor(calibratedRed: 0.17, green: 0.22, blue: 0.36, alpha: 1),
])!.draw(in: squircle, angle: 90)

func tinted(_ image: NSImage, _ color: NSColor) -> NSImage {
    let copy = NSImage(size: image.size)
    copy.lockFocus()
    image.draw(at: .zero, from: .zero, operation: .sourceOver, fraction: 1)
    color.set()
    NSRect(origin: .zero, size: image.size).fill(using: .sourceAtop)
    copy.unlockFocus()
    return copy
}

if let logo = NSImage(contentsOfFile: "Assets/logo.png") {
    let mark = tinted(logo, NSColor(calibratedRed: 0.62, green: 0.80, blue: 1.0, alpha: 1))
    let targetWidth = side * 0.66
    let scale = targetWidth / mark.size.width
    let targetSize = NSSize(width: targetWidth, height: mark.size.height * scale)
    mark.draw(
        in: NSRect(
            x: (CGFloat(px) - targetSize.width) / 2,
            y: (CGFloat(px) - targetSize.height) / 2,
            width: targetSize.width, height: targetSize.height
        ),
        from: .zero, operation: .sourceOver, fraction: 1
    )
}

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
