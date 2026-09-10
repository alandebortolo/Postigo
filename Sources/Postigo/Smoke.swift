import CoreVideo
import Foundation
import PostigoCore

enum Smoke {
    static func run() {
        var failures = 0
        func check(_ cond: Bool, _ name: String) {
            if cond {
                fputs("ok  \(name)\n", stdout)
            } else {
                fputs("FAIL \(name)\n", stderr)
                failures += 1
            }
        }

        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("postigo-smoke-\(UUID().uuidString)", isDirectory: true)
        let layout = StorageLayout(root: dir)
        do { try layout.ensureFolders() } catch {
            fputs("FAIL folders \(error)\n", stderr)
            exit(1)
        }

        let prefs = Preferences(pin: "2580")
        check(prefs.sanitizedPIN == "2580", "pin")
        check(RecordingNamer.isProtected(fileName: "x_motion.mp4"), "namer-protected")

        let old = dir.appendingPathComponent("Recordings/old.mp4")
        try? Data(repeating: 1, count: 400).write(to: old)
        let motion = dir.appendingPathComponent("Recordings/now_motion.mp4")
        try? Data(repeating: 1, count: 400).write(to: motion)
        let files = DiskQuota.scan(root: dir)
        let result = DiskQuota.enforce(
            files: files,
            quotaBytes: 500,
            maxAge: 3600 * 48,
            warnPercent: 80
        )
        for url in result.deleted { try? FileManager.default.removeItem(at: url) }
        check(!result.stillOverQuota || DiskQuota.scan(root: dir).contains { RecordingNamer.isProtected(fileName: $0.url.lastPathComponent) }, "quota")

        let log = EventLog(root: dir)
        log.append(LogEvent(kind: .launched, detail: "smoke"))
        check(log.formatted().contains("launched"), "event-log")

        let detector = MotionDetector(warmupFrames: 1)
        var black = [UInt8](repeating: 0, count: 80 * 40 * 4)
        var white = [UInt8](repeating: 255, count: 80 * 40 * 4)
        for i in 0..<black.count where i % 4 == 3 { black[i] = 255; white[i] = 255 }
        _ = black.withUnsafeBytes { detector.push(bgra: $0.baseAddress!, width: 80, height: 40, bytesPerRow: 320, now: Date()) }
        var sawStart = false
        for _ in 0..<6 {
            let s = white.withUnsafeBytes { detector.push(bgra: $0.baseAddress!, width: 80, height: 40, bytesPerRow: 320, now: Date()) }
            if s.event == .started { sawStart = true }
        }
        check(sawStart, "motion-start")
        var topInk = 0
        var bottomInk = 0
        let stampOK = stampSitsUprightAtBottom(topInk: &topInk, bottomInk: &bottomInk)
        if !stampOK {
            fputs("timestamp ink top=\(topInk) bottom=\(bottomInk)\n", stderr)
        }
        check(stampOK, "timestamp-bottom")

        try? FileManager.default.removeItem(at: dir)
        if failures > 0 {
            fputs("smoke failed: \(failures)\n", stderr)
            exit(1)
        }
        fputs("Postigo smoke ok\n", stdout)
        exit(0)
    }

    /// White frame + overlay: ink must land in the lower half (pixel-buffer y grows downward).
    private static func stampSitsUprightAtBottom(topInk: inout Int, bottomInk: inout Int) -> Bool {
        var buffer: CVPixelBuffer?
        let attrs: [CFString: Any] = [
            kCVPixelBufferIOSurfacePropertiesKey: [:] as CFDictionary,
        ]
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            640,
            160,
            kCVPixelFormatType_32BGRA,
            attrs as CFDictionary,
            &buffer
        )
        guard status == kCVReturnSuccess, let buffer else { return false }
        CVPixelBufferLockBaseAddress(buffer, [])
        let width = CVPixelBufferGetWidth(buffer)
        let height = CVPixelBufferGetHeight(buffer)
        let bpr = CVPixelBufferGetBytesPerRow(buffer)
        if let base = CVPixelBufferGetBaseAddress(buffer) {
            let p = base.bindMemory(to: UInt8.self, capacity: bpr * height)
            for y in 0..<height {
                for x in 0..<width {
                    let i = y * bpr + x * 4
                    p[i] = 255
                    p[i + 1] = 255
                    p[i + 2] = 255
                    p[i + 3] = 255
                }
            }
        }
        CVPixelBufferUnlockBaseAddress(buffer, [])
        TimestampOverlay.draw(on: buffer, now: Date(timeIntervalSince1970: 1_746_000_000))

        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(buffer) else { return false }
        let p = base.bindMemory(to: UInt8.self, capacity: bpr * height)
        for y in 0..<height {
            var rowInk = 0
            for x in 0..<width {
                let i = y * bpr + x * 4
                if p[i] < 200 || p[i + 1] < 200 || p[i + 2] < 200 {
                    rowInk += 1
                }
            }
            if y < height / 2 {
                topInk += rowInk
            } else {
                bottomInk += rowInk
            }
        }
        return bottomInk > 200 && bottomInk > topInk * 4
    }
}
