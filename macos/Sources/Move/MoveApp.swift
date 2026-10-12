import AppKit
import MoveCore

@main
@MainActor
final class MoveApp: NSObject, NSApplicationDelegate {
    private var coordinator: ReminderCoordinator?

    static func main() {
        let app = NSApplication.shared
        let delegate = MoveApp()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        coordinator = ReminderCoordinator(store: .default)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        coordinator?.openSettings()
        return false
    }
}
