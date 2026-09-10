import AppKit
import DeskCamCore

final class EventLogWindowController {
    private var window: NSWindow?
    private var textView: NSTextView?
    private var loader: () -> String

    init(loader: @escaping () -> String) {
        self.loader = loader
    }

    func show() {
        if window == nil { build() }
        reload()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func reload() {
        textView?.string = loader()
        if let textView {
            textView.scrollToEndOfDocument(nil)
        }
    }

    private func build() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 420),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "DeskCam — eventos"
        window.isReleasedWhenClosed = false

        let scroll = NSScrollView(frame: window.contentView?.bounds ?? .zero)
        scroll.hasVerticalScroller = true
        scroll.autoresizingMask = [.width, .height]
        let text = NSTextView(frame: scroll.bounds)
        text.isEditable = false
        text.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        text.autoresizingMask = [.width, .height]
        scroll.documentView = text
        window.contentView = scroll

        self.window = window
        self.textView = text
    }
}
