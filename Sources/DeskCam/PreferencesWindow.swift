import AppKit
import DeskCamCore
import SwiftUI

final class PreferencesWindowController: NSObject {
    private var window: NSWindow?
    private let store: PreferencesStore
    private var cameras: () -> [CameraInfo]
    private var onChange: (Preferences) -> Void
    private var onPickFolder: () -> Void

    init(
        store: PreferencesStore,
        cameras: @escaping () -> [CameraInfo],
        onChange: @escaping (Preferences) -> Void,
        onPickFolder: @escaping () -> Void
    ) {
        self.store = store
        self.cameras = cameras
        self.onChange = onChange
        self.onPickFolder = onPickFolder
    }

    func show() {
        if window == nil {
            let root = PreferencesView(
                prefs: store.load(),
                cameras: cameras(),
                onSave: { [weak self] prefs in
                    self?.store.save(prefs)
                    self?.onChange(prefs)
                },
                onPickFolder: { [weak self] in
                    self?.onPickFolder()
                }
            )
            let hosting = NSHostingController(rootView: root)
            let window = NSWindow(contentViewController: hosting)
            window.title = "DeskCam"
            window.styleMask = [.titled, .closable]
            window.setContentSize(NSSize(width: 440, height: 560))
            window.isReleasedWhenClosed = false
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

struct PreferencesView: View {
    @State var prefs: Preferences
    let cameras: [CameraInfo]
    let onSave: (Preferences) -> Void
    let onPickFolder: () -> Void

    var body: some View {
        Form {
            Section("Câmera") {
                Picker("Dispositivo", selection: $prefs.cameraUniqueID) {
                    Text("Padrão").tag(String?.none)
                    ForEach(cameras, id: \.uniqueID) { cam in
                        Text(cam.name).tag(Optional(cam.uniqueID))
                    }
                }
            }
            Section("Disco") {
                HStack {
                    Text("Cota")
                    Spacer()
                    Text(String(format: "%.1f GB", prefs.quotaGigabytes))
                }
                Slider(value: Binding(
                    get: { Double(prefs.quotaBytes) / 1_000_000_000.0 },
                    set: { prefs.quotaBytes = Int64($0 * 1_000_000_000) }
                ), in: 1...50, step: 0.5)
                Stepper("Reter \(prefs.retentionHours) h", value: $prefs.retentionHours, in: 6...168, step: 6)
                Text(prefs.recordingsRootPath ?? Preferences.defaultRoot().path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Button("Escolher pasta…", action: onPickFolder)
            }
            Section("Gravação") {
                Toggle("Manual guarda mesmo sem movimento", isOn: $prefs.keepAllWhenManual)
                Toggle("Ausente só guarda movimento", isOn: $prefs.motionOnlyWhenAway)
                HStack {
                    Text("Sensibilidade")
                    Slider(value: Binding(
                        get: { Double(prefs.motionThreshold) },
                        set: { prefs.motionThreshold = Float($0) }
                    ), in: 0.015...0.12)
                }
            }
            Section("Ausente") {
                SecureField("PIN de 4 dígitos", text: $prefs.pin)
                Text("Atalho para acordar: Ctrl+Opt+Cmd+Shift+U")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Toggle("Abrir no login (parado)", isOn: $prefs.openAtLogin)
            }
        }
        .padding(16)
        .frame(minWidth: 400, minHeight: 520)
        .onChange(of: prefs) { _, newValue in
            onSave(newValue)
        }
    }
}
