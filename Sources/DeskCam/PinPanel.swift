import AppKit

final class PinPanel: NSObject, NSTextFieldDelegate {
    var onSubmit: ((String) -> Void)?
    var onCancel: (() -> Void)?

    private var window: NSPanel?
    private var field: NSSecureTextField?
    private var status: NSTextField?

    var isVisible: Bool { window?.isVisible == true }

    func show() {
        if window == nil { build() }
        field?.stringValue = ""
        status?.stringValue = ""
        NSApp.activate(ignoringOtherApps: true)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        window?.makeFirstResponder(field)
        NSCursor.unhide()
    }

    func hide() {
        window?.orderOut(nil)
    }

    func shake() {
        field?.stringValue = ""
        status?.stringValue = "PIN incorreto"
        guard let window else { return }
        let origin = window.frame.origin
        let anim = CAKeyframeAnimation(keyPath: "frameOrigin")
        anim.values = [
            origin,
            NSPoint(x: origin.x + 8, y: origin.y),
            NSPoint(x: origin.x - 8, y: origin.y),
            origin,
        ]
        anim.duration = 0.25
        window.animations = ["frameOrigin": anim]
        window.animator().setFrameOrigin(origin)
        window.makeFirstResponder(field)
    }

    private func build() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 140),
            styleMask: [.titled, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.screenSaverWindow)) + 1)
        panel.title = "DeskCam"
        panel.isOpaque = true
        panel.backgroundColor = NSColor(calibratedWhite: 0.12, alpha: 1)
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let content = NSView(frame: panel.contentRect(forFrameRect: panel.frame))
        let label = NSTextField(labelWithString: "PIN para acordar")
        label.textColor = .white
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.frame = NSRect(x: 20, y: 96, width: 240, height: 20)

        let field = NSSecureTextField(frame: NSRect(x: 20, y: 58, width: 240, height: 24))
        field.font = .monospacedSystemFont(ofSize: 18, weight: .semibold)
        field.alignment = .center
        field.maximumNumberOfLines = 1
        field.delegate = self
        field.placeholderString = "••••"

        let status = NSTextField(labelWithString: "")
        status.textColor = NSColor(calibratedRed: 1, green: 0.55, blue: 0.45, alpha: 1)
        status.font = .systemFont(ofSize: 11)
        status.frame = NSRect(x: 20, y: 28, width: 240, height: 18)
        status.alignment = .center

        content.addSubview(label)
        content.addSubview(field)
        content.addSubview(status)
        panel.contentView = content

        self.window = panel
        self.field = field
        self.status = status
    }

    func controlTextDidChange(_ obj: Notification) {
        guard let field else { return }
        let digits = field.stringValue.filter(\.isNumber)
        if digits != field.stringValue {
            field.stringValue = digits
        }
        if digits.count > 4 {
            field.stringValue = String(digits.prefix(4))
        }
        if field.stringValue.count == 4 {
            onSubmit?(field.stringValue)
        }
    }
}
