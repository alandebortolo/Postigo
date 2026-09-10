import AVFoundation
import AppKit
import DeskCamCore
import SwiftUI

final class PreferencesWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private let store: PreferencesStore
    private var cameras: () -> [CameraInfo]
    private var session: () -> AVCaptureSession
    private var onChange: (Preferences) -> Void
    private var onPickFolder: () -> Void
    private var onPreviewStart: (Preferences) -> Void
    private var onPreviewStop: () -> Void

    var isOpen: Bool { window?.isVisible == true }

    init(
        store: PreferencesStore,
        cameras: @escaping () -> [CameraInfo],
        session: @escaping () -> AVCaptureSession,
        onChange: @escaping (Preferences) -> Void,
        onPickFolder: @escaping () -> Void,
        onPreviewStart: @escaping (Preferences) -> Void,
        onPreviewStop: @escaping () -> Void
    ) {
        self.store = store
        self.cameras = cameras
        self.session = session
        self.onChange = onChange
        self.onPickFolder = onPickFolder
        self.onPreviewStart = onPreviewStart
        self.onPreviewStop = onPreviewStop
    }

    func show() {
        if window == nil {
            let root = PreferencesView(
                prefs: store.load(),
                cameras: cameras(),
                session: session(),
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
            window.title = Brand.name
            window.styleMask = [.titled, .closable]
            window.setContentSize(NSSize(width: 460, height: 760))
            window.isReleasedWhenClosed = false
            window.delegate = self
            self.window = window
        }
        onPreviewStart(store.load())
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        onPreviewStop()
    }
}

struct PreferencesView: View {
    @State var prefs: Preferences
    let cameras: [CameraInfo]
    let session: AVCaptureSession
    let onSave: (Preferences) -> Void
    let onPickFolder: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CameraPreviewView(session: session)
                .frame(maxWidth: .infinity, minHeight: 230, idealHeight: 230, maxHeight: 260)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                )
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
                Text("Qualquer tecla acorda e para a gravação. Mouse não acorda: só marca quem mexeu.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Toggle("Abrir no login (parado)", isOn: $prefs.openAtLogin)
            }
            }
        }
        .padding(16)
        .frame(minWidth: 440, minHeight: 720)
        .onChange(of: prefs) { _, newValue in
            onSave(newValue)
        }
    }
}
