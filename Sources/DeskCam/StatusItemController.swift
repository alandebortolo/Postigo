import AppKit
import DeskCamCore

struct MenuSnapshot {
    var mode: RunMode
    var usedBytes: Int64
    var quotaBytes: Int64
    var warn: Bool
    var cameraOK: Bool
    var motionNow: Bool
    var lastError: String?
    var hotkeyLabel: String
}

final class StatusItemController: NSObject {
    var onRecord: (() -> Void)?
    var onStop: (() -> Void)?
    var onAway: (() -> Void)?
    var onOpenFolder: (() -> Void)?
    var onLastClip: (() -> Void)?
    var onPrefs: (() -> Void)?
    var onLog: (() -> Void)?
    var onQuit: (() -> Void)?

    private let item: NSStatusItem
    private var snapshot = MenuSnapshot(
        mode: .idle,
        usedBytes: 0,
        quotaBytes: 5_000_000_000,
        warn: false,
        cameraOK: true,
        motionNow: false,
        lastError: nil,
        hotkeyLabel: "Ctrl+Opt+Cmd+Shift+U"
    )

    override init() {
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        item.button?.toolTip = Brand.name
        applyIcon()
        rebuild()
    }

    func update(_ snapshot: MenuSnapshot) {
        self.snapshot = snapshot
        applyIcon()
        rebuild()
    }

    private func applyIcon() {
        item.button?.image = PostigoMark.statusImage(mode: snapshot.mode, warn: snapshot.warn)
    }

    private func rebuild() {
        let menu = NSMenu()
        menu.autoenablesItems = false

        let state = NSMenuItem(title: stateTitle(), action: nil, keyEquivalent: "")
        state.isEnabled = false
        menu.addItem(state)

        if snapshot.motionNow, snapshot.mode != .idle {
            let m = NSMenuItem(title: "Movimento agora", action: nil, keyEquivalent: "")
            m.isEnabled = false
            menu.addItem(m)
        }

        if let lastError = snapshot.lastError, !lastError.isEmpty {
            let err = NSMenuItem(title: lastError, action: nil, keyEquivalent: "")
            err.isEnabled = false
            menu.addItem(err)
        }

        menu.addItem(.separator())

        let record = NSMenuItem(title: "Gravar", action: #selector(recordClicked), keyEquivalent: "")
        record.target = self
        record.isEnabled = snapshot.mode == .idle && snapshot.cameraOK
        menu.addItem(record)

        let stop = NSMenuItem(title: "Parar", action: #selector(stopClicked), keyEquivalent: "")
        stop.target = self
        stop.isEnabled = snapshot.mode != .idle
        menu.addItem(stop)

        let away = NSMenuItem(title: "Sair da sala", action: #selector(awayClicked), keyEquivalent: "")
        away.target = self
        away.isEnabled = snapshot.mode != .away && snapshot.cameraOK
        menu.addItem(away)

        menu.addItem(.separator())

        let disk = NSMenuItem(title: diskTitle(), action: nil, keyEquivalent: "")
        disk.isEnabled = false
        menu.addItem(disk)

        let folder = NSMenuItem(title: "Abrir pasta", action: #selector(folderClicked), keyEquivalent: "")
        folder.target = self
        menu.addItem(folder)

        let last = NSMenuItem(title: "Último clipe", action: #selector(lastClicked), keyEquivalent: "")
        last.target = self
        menu.addItem(last)

        menu.addItem(.separator())

        let prefs = NSMenuItem(title: "Preferências…", action: #selector(prefsClicked), keyEquivalent: ",")
        prefs.target = self
        prefs.isEnabled = snapshot.mode != .away
        menu.addItem(prefs)

        let log = NSMenuItem(title: "Registro de eventos", action: #selector(logClicked), keyEquivalent: "")
        log.target = self
        log.isEnabled = snapshot.mode != .away
        menu.addItem(log)

        let hotkey = NSMenuItem(title: "Acordar: \(snapshot.hotkeyLabel)", action: nil, keyEquivalent: "")
        hotkey.isEnabled = false
        menu.addItem(hotkey)

        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Sair", action: #selector(quitClicked), keyEquivalent: "q")
        quit.target = self
        quit.isEnabled = snapshot.mode != .away
        menu.addItem(quit)

        item.menu = menu
    }

    private func stateTitle() -> String {
        switch snapshot.mode {
        case .idle: return "Parado"
        case .recording: return "Gravando"
        case .away: return "Ausente (gravando)"
        }
    }

    private func diskTitle() -> String {
        let used = ByteFormat.string(snapshot.usedBytes)
        let quota = ByteFormat.string(snapshot.quotaBytes)
        if snapshot.warn {
            return "Disco: \(used) / \(quota) (alto)"
        }
        return "Disco: \(used) / \(quota)"
    }

    @objc private func recordClicked() { onRecord?() }
    @objc private func stopClicked() { onStop?() }
    @objc private func awayClicked() { onAway?() }
    @objc private func folderClicked() { onOpenFolder?() }
    @objc private func lastClicked() { onLastClip?() }
    @objc private func prefsClicked() { onPrefs?() }
    @objc private func logClicked() { onLog?() }
    @objc private func quitClicked() { onQuit?() }
}
