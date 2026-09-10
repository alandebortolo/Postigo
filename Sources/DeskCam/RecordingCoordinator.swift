import AVFoundation
import CoreVideo
import DeskCamCore
import Foundation

enum RecordPolicy: Equatable {
    case keepAll
    case motionOnly
}

final class RecordingCoordinator {
    var onEvent: ((LogEvent) -> Void)?
    var onQuota: ((QuotaResult) -> Void)?
    var onError: ((String) -> Void)?
    var onMotionChange: ((Bool) -> Void)?

    private let camera = CameraManager()
    private let writer = SegmentWriter()
    private var detector = MotionDetector()
    private var layout: StorageLayout
    private var prefs: Preferences
    private var policy: RecordPolicy = .keepAll
    private var running = false
    private var rotating = false
    private var hadMotionInSegment = false
    private var pendingPreRoll: URL?
    private var segmentWallStart: Date?
    private var lastSnapshotAt: Date?
    private var inMotion = false
    private var currentTempURL: URL?

    init() {
        layout = StorageLayout(root: Preferences.defaultRoot())
        prefs = Preferences()
        camera.onFrame = { [weak self] buffer, time in
            self?.handleFrame(buffer, time: time)
        }
        camera.onError = { [weak self] message in
            self?.onError?(message)
        }
    }

    var captureQueue: DispatchQueue { camera.queue }

    func listCameras() -> [CameraInfo] { camera.listCameras() }

    func authorization() -> AVAuthorizationStatus { camera.authorization() }

    func requestAccess(completion: @escaping (Bool) -> Void) {
        camera.requestAccess(completion: completion)
    }

    func start(layout: StorageLayout, prefs: Preferences, policy: RecordPolicy) {
        captureQueue.async { [weak self] in
            self?._start(layout: layout, prefs: prefs, policy: policy)
        }
    }

    func stop(completion: (() -> Void)? = nil) {
        captureQueue.async { [weak self] in
            self?._stop()
            completion?()
        }
    }

    func stopAndWait() {
        let group = DispatchGroup()
        group.enter()
        stop { group.leave() }
        _ = group.wait(timeout: .now() + 8)
    }

    func markIntrusion() {
        captureQueue.async { [weak self] in
            guard let self, self.running else { return }
            self.hadMotionInSegment = true
            if !self.inMotion {
                self.inMotion = true
                self.onMotionChange?(true)
                self.onEvent?(LogEvent(kind: .intrusion, detail: "movimento no ausente"))
                self.promotePreRoll()
                self.snapshotIfNeeded(buffer: nil, force: true)
            }
        }
    }

    func applyQuotaNow() {
        captureQueue.async { [weak self] in
            self?.enforceQuota()
        }
    }

    private func _start(layout: StorageLayout, prefs: Preferences, policy: RecordPolicy) {
        if running { _stop() }
        self.layout = layout
        self.prefs = prefs
        self.policy = policy
        detector = MotionDetector(
            threshold: prefs.motionThreshold,
            consecutiveNeeded: 3,
            trailing: TimeInterval(prefs.trailingSeconds)
        )
        do {
            try layout.ensureFolders()
            try camera.start(
                cameraID: prefs.cameraUniqueID,
                width: prefs.width,
                height: prefs.height,
                fps: prefs.fps
            )
            running = true
            openSegment()
            onEvent?(LogEvent(
                kind: .recordStart,
                detail: policy == .keepAll ? "keepAll" : "motionOnly"
            ))
        } catch {
            running = false
            onError?(error.localizedDescription)
            onEvent?(LogEvent(kind: .cameraError, detail: error.localizedDescription))
        }
    }

    private func _stop() {
        guard running || writer.url != nil else {
            camera.stop()
            return
        }
        running = false
        camera.stop()
        closeSegment(keepIfMotionOnly: hadMotionInSegment)
        discardUnusedPreRoll()
        detector.reset()
        inMotion = false
        onMotionChange?(false)
        onEvent?(LogEvent(kind: .recordStop, detail: ""))
        enforceQuota()
    }

    private func handleFrame(_ buffer: CVPixelBuffer, time: CMTime) {
        guard running, !rotating else { return }
        let now = Date()

        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        let motion: MotionSample
        if let base = CVPixelBufferGetBaseAddress(buffer) {
            motion = detector.push(
                bgra: base,
                width: CVPixelBufferGetWidth(buffer),
                height: CVPixelBufferGetHeight(buffer),
                bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                now: now
            )
        } else {
            motion = MotionSample(score: 0, event: .none)
        }
        CVPixelBufferUnlockBaseAddress(buffer, .readOnly)

        switch motion.event {
        case .started:
            hadMotionInSegment = true
            inMotion = true
            onMotionChange?(true)
            onEvent?(LogEvent(kind: .motion, detail: String(format: "score=%.3f", motion.score)))
            promotePreRoll()
            TimestampOverlay.draw(on: buffer, now: now)
            snapshotIfNeeded(buffer: buffer, force: true)
        case .ongoing:
            hadMotionInSegment = true
            inMotion = true
            TimestampOverlay.draw(on: buffer, now: now)
            snapshotIfNeeded(buffer: buffer, force: false)
        case .ended:
            inMotion = false
            onMotionChange?(false)
            onEvent?(LogEvent(kind: .motionEnd, detail: ""))
            TimestampOverlay.draw(on: buffer, now: now)
        case .none:
            TimestampOverlay.draw(on: buffer, now: now)
        }

        _ = writer.append(pixelBuffer: buffer, time: time)

        let limit = TimeInterval(policy == .keepAll ? prefs.manualSegmentSeconds : prefs.motionSegmentSeconds)
        if let segmentWallStart, now.timeIntervalSince(segmentWallStart) >= limit {
            rotate()
        }
    }

    private func openSegment() {
        let url = layout.temp.appendingPathComponent("seg-\(UUID().uuidString).mp4")
        do {
            try writer.start(url: url, width: prefs.width, height: prefs.height, fps: prefs.fps, bitrate: prefs.bitrate)
            currentTempURL = url
            segmentWallStart = Date()
            hadMotionInSegment = inMotion
        } catch {
            onError?(error.localizedDescription)
            onEvent?(LogEvent(kind: .cameraError, detail: error.localizedDescription))
        }
    }

    private func rotate() {
        rotating = true
        let keep = hadMotionInSegment
        writer.finish { [weak self] in
            guard let self else { return }
            self.captureQueue.async {
                self.closeFinishedFile(keepIfMotionOnly: keep)
                if self.running {
                    self.openSegment()
                }
                self.rotating = false
                self.enforceQuota()
            }
        }
    }

    private func closeSegment(keepIfMotionOnly: Bool) {
        rotating = true
        let group = DispatchGroup()
        group.enter()
        writer.finish { group.leave() }
        _ = group.wait(timeout: .now() + 6)
        closeFinishedFile(keepIfMotionOnly: keepIfMotionOnly)
        rotating = false
    }

    private func closeFinishedFile(keepIfMotionOnly: Bool) {
        guard let temp = currentTempURL else { return }
        currentTempURL = nil
        let size = (try? FileManager.default.attributesOfItem(atPath: temp.path)[.size] as? NSNumber)?.int64Value ?? 0
        if size < 16_000 {
            try? FileManager.default.removeItem(at: temp)
            return
        }

        if policy == .keepAll {
            commit(temp, kind: .continuous)
            return
        }

        if keepIfMotionOnly {
            commit(temp, kind: .motion)
            return
        }

        if let old = pendingPreRoll {
            try? FileManager.default.removeItem(at: old)
        }
        pendingPreRoll = temp
    }

    private func promotePreRoll() {
        guard let pendingPreRoll else { return }
        self.pendingPreRoll = nil
        commit(pendingPreRoll, kind: .preroll)
    }

    private func discardUnusedPreRoll() {
        if let pendingPreRoll {
            try? FileManager.default.removeItem(at: pendingPreRoll)
            self.pendingPreRoll = nil
        }
    }

    private func commit(_ temp: URL, kind: ClipKind) {
        let dest = layout.recordings.appendingPathComponent(RecordingNamer.fileName(date: Date(), kind: kind))
        do {
            if FileManager.default.fileExists(atPath: dest.path) {
                try FileManager.default.removeItem(at: dest)
            }
            try FileManager.default.moveItem(at: temp, to: dest)
        } catch {
            try? FileManager.default.removeItem(at: temp)
        }
    }

    private func snapshotIfNeeded(buffer: CVPixelBuffer?, force: Bool) {
        let now = Date()
        if !force, let lastSnapshotAt, now.timeIntervalSince(lastSnapshotAt) < TimeInterval(prefs.snapshotEveryMotionSeconds) {
            return
        }
        guard let buffer else { return }
        lastSnapshotAt = now
        let url = layout.snapshots.appendingPathComponent(RecordingNamer.fileName(date: now, kind: .snapshot))
        do {
            try SnapshotWriter.writeJPEG(buffer: buffer, to: url)
        } catch {
            // Snapshot is best-effort; video is the source of truth.
        }
    }

    private func enforceQuota() {
        let files = DiskQuota.scan(root: layout.root)
        let result = DiskQuota.enforce(
            files: files,
            quotaBytes: prefs.quotaBytes,
            maxAge: TimeInterval(prefs.retentionHours * 3600),
            warnPercent: prefs.quotaWarnPercent
        )
        for url in result.deleted {
            try? FileManager.default.removeItem(at: url)
        }
        let used = DiskQuota.scan(root: layout.root).reduce(Int64(0)) { $0 + $1.bytes }
        var adjusted = result
        adjusted.usedBytes = used
        if result.warn {
            onEvent?(LogEvent(kind: .quotaWarn, detail: ByteFormat.string(used)))
        }
        if result.stillOverQuota {
            onEvent?(LogEvent(kind: .quotaStop, detail: ByteFormat.string(used)))
        }
        onQuota?(adjusted)
    }
}
