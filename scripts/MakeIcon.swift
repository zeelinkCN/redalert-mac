import AppKit
import Foundation

let destination = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)

func render(_ size: Int) throws -> Data {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    let context = NSGraphicsContext.current!.cgContext
    context.scaleBy(x: CGFloat(size) / 1024, y: CGFloat(size) / 1024)
    NSColor(calibratedRed: 0.075, green: 0.086, blue: 0.094, alpha: 1).setFill()
    NSBezierPath(roundedRect: NSRect(x: 64, y: 64, width: 896, height: 896), xRadius: 202, yRadius: 202).fill()
    let red = NSColor(calibratedRed: 0.94, green: 0.31, blue: 0.26, alpha: 1)
    red.withAlphaComponent(0.15).setStroke()
    for radius in [CGFloat(270), CGFloat(340)] {
        let ring = NSBezierPath(ovalIn: NSRect(x: 512-radius, y: 512-radius, width: radius*2, height: radius*2))
        ring.lineWidth = 3; ring.stroke()
    }
    red.setFill()
    let star = NSBezierPath()
    for index in 0..<10 {
        let angle = CGFloat.pi / 2 + CGFloat(index) * CGFloat.pi / 5
        let radius: CGFloat = index.isMultiple(of: 2) ? 244 : 116
        let point = NSPoint(x: 512 + cos(angle)*radius, y: 554 + sin(angle)*radius)
        if index == 0 { star.move(to: point) } else { star.line(to: point) }
    }
    star.close(); star.fill()
    let text: NSString = "RED ALERT"
    let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.monospacedSystemFont(ofSize: 49, weight: .bold), .foregroundColor: NSColor(white: 0.88, alpha: 1), .kern: 10]
    let textSize = text.size(withAttributes: attributes)
    text.draw(at: NSPoint(x: (1024-textSize.width)/2, y: 230), withAttributes: attributes)
    red.setFill(); NSBezierPath(roundedRect: NSRect(x: 444, y: 171, width: 136, height: 7), xRadius: 3, yRadius: 3).fill()
    NSGraphicsContext.restoreGraphicsState()
    return bitmap.representation(using: .png, properties: [:])!
}
for base in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let filename = "icon_\(base)x\(base)\(scale == 2 ? "@2x" : "").png"
        try render(base*scale).write(to: destination.appendingPathComponent(filename))
    }
}
