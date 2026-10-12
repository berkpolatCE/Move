import AppKit

enum Presence {
    case available
    case fullscreen
    case away
}

@MainActor
enum UserActivity {
    static var idleTime: TimeInterval {
        CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: CGEventType(rawValue: ~0)!)
    }

    static func presence() -> Presence {
        if isAway {
            return .away
        }

        let displays = NSScreen.screens.map(\.displayBounds)
        let isFullscreen = frontmostWindows().contains { window in displays.contains { window.contains($0) } }
        return isFullscreen ? .fullscreen : .available
    }

    static var activeScreen: NSScreen? {
        guard let window = frontmostWindows().first else {
            return NSScreen.main
        }

        let center = CGPoint(x: window.midX, y: window.midY)
        return NSScreen.screens.first { $0.displayBounds.contains(center) } ?? NSScreen.main
    }

    private static var isAway: Bool {
        let session = CGSessionCopyCurrentDictionary() as? [String: Any]
        return session?["CGSSessionScreenIsLocked"] as? Bool == true
            || session?["kCGSSessionOnConsoleKey"] as? Bool == false
            || CGDisplayIsAsleep(CGMainDisplayID()) != 0
            || NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == "com.apple.ScreenSaver.Engine" }
    }

    private static func frontmostWindows() -> [CGRect] {
        guard let app = NSWorkspace.shared.frontmostApplication,
              app != .current,
              let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
                as? [[String: Any]]
        else {
            return []
        }

        return windows.compactMap { window in
            guard window[kCGWindowOwnerPID as String] as? pid_t == app.processIdentifier,
                  window[kCGWindowAlpha as String] as? Double ?? 0 > 0,
                  let bounds = window[kCGWindowBounds as String] as? NSDictionary
            else {
                return nil
            }

            return CGRect(dictionaryRepresentation: bounds)
        }
    }
}

extension NSScreen {
    var displayBounds: CGRect {
        CGDisplayBounds((deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0)
    }
}
