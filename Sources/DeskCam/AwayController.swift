import AppKit
import DeskCamCore

final class AwayController {
    var onWake: (() -> Void)?
    var onIntrusion: (() -> Void)?

    private let overlay = OverlayController()
    private let brightness: BrightnessController
    private let assertion = SleepAssertion()
    private let flagURL: URL
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var lastIntrusionLog = Date.distantPast
    private var waking = false
    private(set) var isAway = false

    init(flagURL: URL) {
        self.flagURL = flagURL
        brightness = BrightnessController(flagURL: flagURL)
    }

    func recoverIfNeeded() -> Bool {
        let existed = FileManager.default.fileExists(atPath: flagURL.path)
        brightness.recoverIfNeeded()
        NSApp.presentationOptions = []
        NSCursor.unhide()
        return existed
    }

    func enter() {
        guard !isAway else { return }
        isAway = true
        waking = false
        assertion.take()
        NSApp.presentationOptions = [.hideDock, .hideMenuBar, .disableAppleMenu]
        overlay.show()
        brightness.dimAll()
        NSCursor.hide()
        installMonitors()
    }

    func exit() {
        guard isAway else {
            restoreChrome()
            return
        }
        isAway = false
        waking = false
        removeMonitors()
        restoreChrome()
        assertion.release()
    }

    private func restoreChrome() {
        brightness.restore()
        overlay.hide()
        NSApp.presentationOptions = []
        NSCursor.unhide()
    }

    private func installMonitors() {
        removeMonitors()
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDown, .rightMouseDown, .keyDown, .scrollWheel]) { [weak self] event in
            self?.handle(event)
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDown, .rightMouseDown, .keyDown, .scrollWheel]) { [weak self] event in
            self?.handle(event)
            return event
        }
    }

    private func handle(_ event: NSEvent) {
        if event.type == .keyDown {
            wake()
            return
        }
        noteIntrusion()
    }

    private func wake() {
        guard isAway, !waking else { return }
        waking = true
        onWake?()
    }

    private func removeMonitors() {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
    }

    private func noteIntrusion() {
        let now = Date()
        if now.timeIntervalSince(lastIntrusionLog) < 20 { return }
        lastIntrusionLog = now
        onIntrusion?()
    }
}
