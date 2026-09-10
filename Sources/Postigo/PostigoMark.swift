import AppKit
import PostigoCore

enum PostigoMark {
    static func statusImage(mode: RunMode, warn: Bool) -> NSImage {
        let points = NSSize(width: 18, height: 18)
        let scale: CGFloat = 2
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(points.width * scale),
            pixelsHigh: Int(points.height * scale),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )!
        rep.size = points
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSGraphicsContext.current?.shouldAntialias = true

        NSColor.black.setStroke()
        NSColor.black.setFill()

        let door = NSBezierPath(roundedRect: NSRect(x: 4.4, y: 1.4, width: 9.2, height: 15.2), xRadius: 2.1, yRadius: 2.1)
        door.lineWidth = 1.35
        door.stroke()

        let window = NSRect(x: 6.15, y: 9.35, width: 5.7, height: 3.55)
        let windowPath = NSBezierPath(roundedRect: window, xRadius: 0.7, yRadius: 0.7)
        windowPath.lineWidth = 1.05

        let slit = NSBezierPath(roundedRect: NSRect(x: 6.85, y: 10.45, width: 4.3, height: 1.35), xRadius: 0.45, yRadius: 0.45)

        switch mode {
        case .idle:
            windowPath.stroke()
            slit.lineWidth = 1.0
            slit.stroke()
        case .recording:
            windowPath.stroke()
            slit.fill()
        case .away:
            windowPath.fill()
        }

        if warn {
            NSBezierPath(ovalIn: NSRect(x: 13.6, y: 1.4, width: 2.6, height: 2.6)).fill()
        }

        NSGraphicsContext.restoreGraphicsState()

        let image = NSImage(size: points)
        image.addRepresentation(rep)
        image.isTemplate = true
        image.accessibilityDescription = Brand.name
        return image
    }
}
