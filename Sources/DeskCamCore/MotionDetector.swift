import Foundation

public struct MotionSample: Equatable {
    public var score: Float
    public var event: MotionEvent

    public init(score: Float, event: MotionEvent) {
        self.score = score
        self.event = event
    }
}

public enum MotionEvent: Equatable {
    case none
    case started
    case ongoing
    case ended
}

/// Downscales BGRA frames and compares luma against a quiet-scene background.
/// A person who walks in and stands still still counts as motion. Timestamp
/// overlays must be drawn AFTER this runs, or the ticking clock looks like motion.
public final class MotionDetector {
    public var threshold: Float
    public var consecutiveNeeded: Int
    public var trailing: TimeInterval
    public let outWidth: Int
    public let outHeight: Int

    private var background: [Float]
    private var warmupLeft: Int
    private var hotStreak = 0
    private var inMotion = false
    private var lastHotAt: Date?

    public init(
        threshold: Float = 0.045,
        consecutiveNeeded: Int = 3,
        trailing: TimeInterval = 10,
        outWidth: Int = 160,
        outHeight: Int = 90,
        warmupFrames: Int = 8
    ) {
        self.threshold = threshold
        self.consecutiveNeeded = consecutiveNeeded
        self.trailing = trailing
        self.outWidth = outWidth
        self.outHeight = outHeight
        self.warmupLeft = warmupFrames
        self.background = [Float](repeating: 0, count: outWidth * outHeight)
    }

    public func reset() {
        background = [Float](repeating: 0, count: outWidth * outHeight)
        warmupLeft = 8
        hotStreak = 0
        inMotion = false
        lastHotAt = nil
    }

    public func push(
        bgra: UnsafeRawPointer,
        width: Int,
        height: Int,
        bytesPerRow: Int,
        now: Date
    ) -> MotionSample {
        var current = [Float](repeating: 0, count: outWidth * outHeight)
        downsampleLuma(bgra: bgra, width: width, height: height, bytesPerRow: bytesPerRow, into: &current)

        if warmupLeft > 0 {
            warmupLeft -= 1
            background = current
            return MotionSample(score: 0, event: .none)
        }

        var acc: Float = 0
        for i in 0..<current.count {
            acc += abs(current[i] - background[i])
        }
        let score = acc / Float(current.count * 255)

        let hot = score >= threshold
        if hot {
            hotStreak += 1
            lastHotAt = now
        } else {
            hotStreak = 0
            if !inMotion {
                for i in 0..<background.count {
                    background[i] = background[i] * 0.9 + current[i] * 0.1
                }
            }
        }

        if !inMotion {
            if hotStreak >= consecutiveNeeded {
                inMotion = true
                return MotionSample(score: score, event: .started)
            }
            return MotionSample(score: score, event: .none)
        }

        if hot {
            return MotionSample(score: score, event: .ongoing)
        }
        if let lastHotAt, now.timeIntervalSince(lastHotAt) < trailing {
            return MotionSample(score: score, event: .ongoing)
        }
        inMotion = false
        background = current
        return MotionSample(score: score, event: .ended)
    }

    private func downsampleLuma(
        bgra: UnsafeRawPointer,
        width: Int,
        height: Int,
        bytesPerRow: Int,
        into out: inout [Float]
    ) {
        guard width > 0, height > 0 else { return }
        let base = bgra.assumingMemoryBound(to: UInt8.self)
        for y in 0..<outHeight {
            let srcY = min(height - 1, y * height / outHeight)
            let row = base.advanced(by: srcY * bytesPerRow)
            for x in 0..<outWidth {
                let srcX = min(width - 1, x * width / outWidth)
                let p = row.advanced(by: srcX * 4)
                let b = Float(p[0])
                let g = Float(p[1])
                let r = Float(p[2])
                out[y * outWidth + x] = (r * 0.299 + g * 0.587 + b * 0.114)
            }
        }
    }
}
