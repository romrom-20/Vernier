import AppKit

let destination = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
func color(_ hex: UInt32, alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255, blue: CGFloat(hex & 255) / 255, alpha: alpha)
}
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        NSGraphicsContext.current!.cgContext.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
        let plate = NSBezierPath(roundedRect: NSRect(x: 70, y: 70, width: 884, height: 884), xRadius: 202, yRadius: 202)
        NSGradient(starting: color(0x1D2B2D), ending: color(0x0B1012))!.draw(in: plate, angle: -75)
        color(0x52655C, alpha: 0.55).setStroke(); plate.lineWidth = 2; plate.stroke()
        let circle = NSBezierPath(ovalIn: NSRect(x: 255, y: 255, width: 514, height: 514))
        color(0x52655C).setStroke(); circle.lineWidth = 5; circle.stroke()
        let mint = color(0xB7E5BE)
        mint.setStroke()
        let mark = NSBezierPath()
        mark.move(to: NSPoint(x: 512, y: 204)); mark.line(to: NSPoint(x: 512, y: 820))
        mark.move(to: NSPoint(x: 340, y: 425)); mark.line(to: NSPoint(x: 684, y: 425))
        mark.move(to: NSPoint(x: 402, y: 635)); mark.line(to: NSPoint(x: 622, y: 635))
        mark.lineWidth = 13; mark.lineCapStyle = .round; mark.stroke()
        if pixels >= 128 {
            color(0x7E9686, alpha: 0.7).setStroke()
            for index in 0..<24 {
                let angle = CGFloat(index) * .pi / 12
                let outer: CGFloat = index.isMultiple(of: 3) ? 335 : 328
                let tick = NSBezierPath()
                tick.move(to: NSPoint(x: 512 + cos(angle) * 316, y: 512 + sin(angle) * 316))
                tick.line(to: NSPoint(x: 512 + cos(angle) * outer, y: 512 + sin(angle) * outer))
                tick.lineWidth = 3; tick.stroke()
            }
        }
        NSGraphicsContext.restoreGraphicsState()
        let suffix = scale == 2 ? "@2x" : ""
        try bitmap.representation(using: .png, properties: [:])!.write(to: destination.appendingPathComponent("icon_\(size)x\(size)\(suffix).png"))
    }
}
