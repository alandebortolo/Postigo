import AppKit

final class OverlayWindow: NSWindow {
    init(screen: NSScreen) {
        super.init(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        isOpaque = true
        backgroundColor = .black
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        ignoresMouseEvents = false
        hidesOnDeactivate = false
        animationBehavior = .none
        isReleasedWhenClosed = false
        hasShadow = false
        isRestorable = false
        contentView = NSView(frame: screen.frame)
        contentView?.wantsLayer = true
        contentView?.layer?.backgroundColor = NSColor.black.cgColor
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

final class OverlayController {
    private var windows: [OverlayWindow] = []
    private var observer: NSObjectProtocol?

    func show() {
        hide()
        rebuild()
        observer = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.rebuild()
        }
    }

    func hide() {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
            self.observer = nil
        }
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()
    }

    private func rebuild() {
        windows.forEach { $0.orderOut(nil) }
        windows = NSScreen.screens.map { screen in
            let w = OverlayWindow(screen: screen)
            w.setFrame(screen.frame, display: true)
            w.orderFrontRegardless()
            return w
        }
    }
}
