import AppKit
import ServiceManagement

@MainActor
enum LoginItem {
    static func apply(_ enabled: Bool) {
        let service = SMAppService.mainApp
        if enabled == (service.status == .enabled) {
            return
        }

        do {
            if enabled {
                try service.register()
            } else {
                try service.unregister()
            }
        } catch {
            let alert = NSAlert()
            alert.messageText = "Move couldn't change its login item"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.runModal()
        }
    }
}
