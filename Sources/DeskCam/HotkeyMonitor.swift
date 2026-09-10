import Carbon
import Foundation

/// Control + Option + Command + Shift + U, registered as a Carbon hotkey (no Accessibility needed).
final class HotkeyMonitor {
    static let shared = HotkeyMonitor()
    var onPressed: (() -> Void)?
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private var installed = false

    var comboLabel: String { "Ctrl+Opt+Cmd+Shift+U" }

    func start() {
        if !installed {
            var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
            InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
                DispatchQueue.main.async {
                    HotkeyMonitor.shared.onPressed?()
                }
                return noErr
            }, 1, &spec, nil, &handlerRef)
            installed = true
        }
        stopKey()
        var ref: EventHotKeyRef?
        let modifiers = UInt32(controlKey | optionKey | cmdKey | shiftKey)
        let id = EventHotKeyID(signature: OSType(0x44434D31), id: 1) // 'DCM1'
        let status = RegisterEventHotKey(UInt32(kVK_ANSI_U), modifiers, id, GetApplicationEventTarget(), 0, &ref)
        if status == noErr {
            hotKeyRef = ref
        } else {
            NSLog("DeskCam: atalho ocupado (%d)", status)
        }
    }

    func stop() {
        stopKey()
    }

    private func stopKey() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }
}
