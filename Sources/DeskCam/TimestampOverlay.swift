import AppKit
import CoreVideo
import Foundation

enum TimestampOverlay {
    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f
    }()

    static func draw(on buffer: CVPixelBuffer, now: Date) {
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        guard let base = CVPixelBufferGetBaseAddress(buffer) else { return }
        let width = CVPixelBufferGetWidth(buffer)
        let height = CVPixelBufferGetHeight(buffer)
        let bpr = CVPixelBufferGetBytesPerRow(buffer)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: base,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bpr,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
        ) else { return }

        let ns = NSGraphicsContext(cgContext: ctx, flipped: true)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = ns

        let text = formatter.string(from: now) as NSString
        let fontSize = max(16, CGFloat(width) / 55)
        let font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .medium)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white,
        ]
        let size = text.size(withAttributes: attrs)
        let pad: CGFloat = 8
        let x: CGFloat = 14
        let y = CGFloat(height) - size.height - 18
        NSColor.black.withAlphaComponent(0.55).setFill()
        NSBezierPath(roundedRect: NSRect(x: x - pad, y: y - 4, width: size.width + pad * 2, height: size.height + 8), xRadius: 4, yRadius: 4).fill()
        text.draw(at: NSPoint(x: x, y: y), withAttributes: attrs)

        NSGraphicsContext.restoreGraphicsState()
    }
}
