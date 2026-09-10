import Foundation
import ServiceManagement

enum LoginItem {
    static func apply(_ on: Bool) {
        do {
            if on {
                try SMAppService.mainApp.register()
            } else if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("Postigo login item: %@", error.localizedDescription)
        }
    }
}
