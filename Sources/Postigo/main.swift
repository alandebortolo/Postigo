import AppKit
import PostigoCore

if CommandLine.arguments.contains("--smoke") {
    Smoke.run()
} else {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var controller: AppController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        controller = AppController()
        controller?.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller?.prepareQuit()
    }
}
