import AppKit
import DeskCamCore

final class AwayController {
    var onWake: (() -> Void)?
    var onIntrusion: (() -> Void)?
    var onPinFail: (() -> Void)?

    private let overlay = OverlayController()
    private let pin = PinPanel()
    private let brightness: BrightnessController
    private let assertion = SleepAssertion()
    private let flagURL: URL
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var pinCode: String = "1234"
    private var failedAttempts = 0
    private var lastIntrusionLog = Date.distantPast
    private(set) var isAway = false

    init(flagURL: URL) {
        self.flagURL = flagURL
        brightness = BrightnessController(flagURL: flagURL)
        pin.onSubmit = { [weak self] value in
            self?.handlePIN(value)
        }
    }

    func recoverIfNeeded() -> Bool {
        let existed = FileManager.default.fileExists(atPath: flagURL.path)
        brightness.recoverIfNeeded()
        NSApp.presentationOptions = []
        NSCursor.unhide()
        return existed
    }

    func enter(pin: String) {
        guard !isAway else { return }
        isAway = true
        pinCode = pin
        failedAttempts = 0
        assertion.take()
        NSApp.presentationOptions = [.hideDock, .hideMenuBar, .disableAppleMenu]
        overlay.show()
        brightness.dimAll()
        NSCursor.hide()
        installMonitors()
        HotkeyMonitor.shared.onPressed = { [weak self] in
            self?.showPIN()
        }
        HotkeyMonitor.shared.start()
    }

    func exit() {
        guard isAway else {
            restoreChrome()
            return
        }
        isAway = false
        HotkeyMonitor.shared.stop()
        HotkeyMonitor.shared.onPressed = nil
        removeMonitors()
        pin.hide()
        restoreChrome()
        assertion.release()
    }

    func showPIN() {
        guard isAway else { return }
        pin.show()
    }

    private func restoreChrome() {
        brightness.restore()
        overlay.hide()
        NSApp.presentationOptions = []
        NSCursor.unhide()
    }

    private func handlePIN(_ value: String) {
        if value == pinCode {
            pin.hide()
            onWake?()
            return
        }
        failedAttempts += 1
        pin.shake()
        onPinFail?()
        if failedAttempts >= 5 {
            onIntrusion?()
        }
    }

    private func installMonitors() {
        removeMonitors()
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDown, .rightMouseDown, .keyDown, .scrollWheel]) { [weak self] _ in
            self?.noteIntrusion()
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDown, .rightMouseDown, .keyDown, .scrollWheel]) { [weak self] event in
            if event.type == .keyDown, self?.pin.isVisible == true {
                return event
            }
            if event.type == .mouseMoved || event.type == .leftMouseDown || event.type == .rightMouseDown || event.type == .scrollWheel {
                self?.noteIntrusion()
            } else if event.type == .keyDown, self?.pin.isVisible == false {
                self?.noteIntrusion()
            }
            return event
        }
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
