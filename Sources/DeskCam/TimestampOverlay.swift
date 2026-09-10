import CoreGraphics
import CoreText
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

        ctx.saveGState()

        let text = formatter.string(from: now) as CFString
        let fontSize = max(16, CGFloat(width) / 55)
        let font = CTFontCreateWithName("Menlo-Bold" as CFString, fontSize, nil)
        let white = CGColor(gray: 1, alpha: 1)
        let attrs: [CFString: Any] = [
            kCTFontAttributeName: font,
            kCTForegroundColorAttributeName: white,
        ]
        let attributed = CFAttributedStringCreate(kCFAllocatorDefault, text, attrs as CFDictionary)!
        let line = CTLineCreateWithAttributedString(attributed)
        var ascent: CGFloat = 0
        var descent: CGFloat = 0
        var leading: CGFloat = 0
        let lineWidth = CGFloat(CTLineGetTypographicBounds(line, &ascent, &descent, &leading))
        let lineHeight = ascent + descent
        let pad: CGFloat = 8
        let x: CGFloat = 14
        let y: CGFloat = 18

        ctx.setFillColor(gray: 0, alpha: 0.55)
        let badge = CGRect(x: x - pad, y: y - descent - 4, width: lineWidth + pad * 2, height: lineHeight + 8)
        ctx.addPath(CGPath(roundedRect: badge, cornerWidth: 4, cornerHeight: 4, transform: nil))
        ctx.fillPath()

        ctx.textMatrix = .identity
        ctx.textPosition = CGPoint(x: x, y: y)
        CTLineDraw(line, ctx)
        ctx.restoreGState()
    }
}
