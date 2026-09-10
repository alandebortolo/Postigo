import AppKit
import AVFoundation
import DeskCamCore
import Foundation

final class AppController: NSObject {
    private let store = PreferencesStore()
    private var prefs: Preferences
    private var layout: StorageLayout
    private var log: EventLog
    private let recorder = RecordingCoordinator()
    private let status = StatusItemController()
    private var away: AwayController
    private var prefsWindow: PreferencesWindowController!
    private var logWindow: EventLogWindowController!
    private let sleep = SleepAssertion()
    private var mode: RunMode = .idle
    private var usedBytes: Int64 = 0
    private var warn = false
    private var lastError: String?
    private var motionNow = false
    private var failsafeTimer: Timer?
    private var cameraOK = true

    override init() {
        prefs = store.load()
        layout = StorageLayout(root: prefs.resolvedRoot())
        try? layout.ensureFolders()
        log = EventLog(root: layout.root)
        away = AwayController(flagURL: layout.awayFlag)
        super.init()
    }

    func start() {
        if away.recoverIfNeeded() {
            log.append(LogEvent(kind: .crashRecovered, detail: "brilho restaurado"))
        }
        log.append(LogEvent(kind: .launched, detail: ""))
        wire()
        LoginItem.apply(prefs.openAtLogin)
        refreshDisk()
        rebuildMenu()
        failsafeTimer = Timer.scheduledTimer(withTimeInterval: 20, repeats: true) { [weak self] _ in
            self?.failsafeTick()
        }
    }

    func prepareQuit() {
        failsafeTimer?.invalidate()
        if mode == .away {
            away.exit()
        }
        recorder.stopPreview()
        if mode != .idle {
            recorder.stopAndWait()
        }
        sleep.release()
        mode = .idle
    }

    private func wire() {
        status.onRecord = { [weak self] in self?.startRecording() }
        status.onStop = { [weak self] in self?.stopEverything() }
        status.onAway = { [weak self] in self?.enterAway() }
        status.onOpenFolder = { [weak self] in
            guard let self else { return }
            NSWorkspace.shared.open(self.layout.root)
        }
        status.onLastClip = { [weak self] in
            guard let url = self?.layout.newestRecording() else { return }
            NSWorkspace.shared.open(url)
        }
        status.onPrefs = { [weak self] in self?.prefsWindow.show() }
        status.onLog = { [weak self] in self?.logWindow.show() }
        status.onQuit = { [weak self] in
            self?.prepareQuit()
            NSApp.terminate(nil)
        }

        recorder.onEvent = { [weak self] event in
            DispatchQueue.main.async { self?.log.append(event) }
        }
        recorder.onError = { [weak self] message in
            DispatchQueue.main.async {
                self?.lastError = message
                self?.cameraOK = false
                self?.rebuildMenu()
            }
        }
        recorder.onMotionChange = { [weak self] active in
            DispatchQueue.main.async {
                self?.motionNow = active
                self?.rebuildMenu()
            }
        }
        recorder.onQuota = { [weak self] result in
            DispatchQueue.main.async {
                self?.usedBytes = result.usedBytes
                self?.warn = result.warn
                self?.rebuildMenu()
                if result.stillOverQuota {
                    self?.failsafeStop(reason: "cota cheia de clipes protegidos")
                }
            }
        }

        away.onWake = { [weak self] in self?.wakeFromAway() }
        away.onIntrusion = { [weak self] in
            self?.log.append(LogEvent(kind: .intrusion, detail: "mouse no ausente"))
            self?.recorder.markIntrusion()
        }

        prefsWindow = PreferencesWindowController(
            store: store,
            cameras: { [weak self] in self?.recorder.listCameras() ?? [] },
            session: { [weak self] in
                self?.recorder.captureSession ?? AVCaptureSession()
            },
            onChange: { [weak self] prefs in
                guard let self else { return }
                self.prefs = prefs
                LoginItem.apply(prefs.openAtLogin)
                self.relocateIfNeeded()
                self.rebuildMenu()
                if self.prefsWindow.isOpen {
                    self.recorder.startPreview(prefs: prefs)
                }
            },
            onPickFolder: { [weak self] in self?.pickFolder() },
            onPreviewStart: { [weak self] prefs in
                guard let self else { return }
                self.recorder.requestAccess { granted in
                    if granted {
                        self.cameraOK = true
                        self.lastError = nil
                        self.recorder.startPreview(prefs: prefs)
                    } else {
                        self.cameraOK = false
                        self.lastError = "Câmera recusada em Ajustes > Privacidade"
                    }
                    self.rebuildMenu()
                }
            },
            onPreviewStop: { [weak self] in
                self?.recorder.stopPreview()
            }
        )
        logWindow = EventLogWindowController { [weak self] in
            self?.log.formatted(limit: 300) ?? ""
        }
    }

    private func startRecording() {
        recorder.requestAccess { [weak self] granted in
            guard let self else { return }
            if !granted {
                self.cameraOK = false
                self.lastError = "Câmera recusada em Ajustes > Privacidade"
                self.rebuildMenu()
                return
            }
            self.cameraOK = true
            self.lastError = nil
            let policy: RecordPolicy = self.prefs.keepAllWhenManual ? .keepAll : .motionOnly
            self.sleep.take()
            self.recorder.start(layout: self.layout, prefs: self.prefs, policy: policy)
            self.mode = .recording
            self.rebuildMenu()
        }
    }

    private func enterAway() {
        recorder.requestAccess { [weak self] granted in
            guard let self else { return }
            if !granted {
                self.cameraOK = false
                self.lastError = "Câmera recusada em Ajustes > Privacidade"
                self.rebuildMenu()
                return
            }
            self.cameraOK = true
            self.lastError = nil
            if self.mode == .idle {
                let policy: RecordPolicy = self.prefs.motionOnlyWhenAway ? .motionOnly : .keepAll
                self.sleep.take()
                self.recorder.start(layout: self.layout, prefs: self.prefs, policy: policy)
            }
            self.mode = .away
            self.away.enter()
            self.log.append(LogEvent(kind: .awayStart, detail: "qualquer tecla"))
            self.rebuildMenu()
        }
    }

    private func wakeFromAway() {
        away.exit()
        log.append(LogEvent(kind: .awayWake, detail: "tecla"))
        recorder.stop { [weak self] in
            DispatchQueue.main.async {
                self?.sleep.release()
                self?.mode = .idle
                self?.motionNow = false
                self?.refreshDisk()
                self?.rebuildMenu()
            }
        }
    }

    private func stopEverything() {
        if mode == .away {
            away.exit()
            log.append(LogEvent(kind: .awayWake, detail: "parar pelo menu"))
        }
        recorder.stop { [weak self] in
            DispatchQueue.main.async {
                self?.sleep.release()
                self?.mode = .idle
                self?.motionNow = false
                self?.refreshDisk()
                self?.rebuildMenu()
            }
        }
    }

    private func failsafeTick() {
        refreshDisk()
        if PowerInfo.current().shouldStop(thresholdPercent: prefs.batteryStopPercent) {
            failsafeStop(reason: "bateria \(prefs.batteryStopPercent)%")
        }
    }

    private func failsafeStop(reason: String) {
        guard mode != .idle else { return }
        log.append(LogEvent(kind: .awayFailsafe, detail: reason))
        lastError = reason
        stopEverything()
    }

    private func refreshDisk() {
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
        usedBytes = DiskQuota.scan(root: layout.root).reduce(0) { $0 + $1.bytes }
        warn = result.warn
        if result.stillOverQuota, mode != .idle {
            failsafeStop(reason: "cota cheia de clipes protegidos")
        }
    }

    private func relocateIfNeeded() {
        let newRoot = prefs.resolvedRoot()
        if newRoot.path != layout.root.path {
            layout = StorageLayout(root: newRoot)
            try? layout.ensureFolders()
            log = EventLog(root: layout.root)
            away = AwayController(flagURL: layout.awayFlag)
            away.onWake = { [weak self] in self?.wakeFromAway() }
            away.onIntrusion = { [weak self] in
                self?.log.append(LogEvent(kind: .intrusion, detail: "mouse no ausente"))
                self?.recorder.markIntrusion()
            }
        }
    }

    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Usar esta pasta"
        panel.directoryURL = layout.root
        NSApp.activate(ignoringOtherApps: true)
        panel.begin { [weak self] response in
            guard let self, response == .OK, let url = panel.url else { return }
            self.prefs.recordingsRootPath = url.path
            self.store.save(self.prefs)
            self.relocateIfNeeded()
            self.refreshDisk()
            self.rebuildMenu()
        }
    }

    private func rebuildMenu() {
        status.update(MenuSnapshot(
            mode: mode,
            usedBytes: usedBytes,
            quotaBytes: prefs.quotaBytes,
            warn: warn,
            cameraOK: cameraOK,
            motionNow: motionNow,
            lastError: lastError,
            hotkeyLabel: "qualquer tecla"
        ))
    }
}
