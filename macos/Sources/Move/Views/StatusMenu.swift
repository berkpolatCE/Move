import AppKit
import SwiftUI

@MainActor
final class StatusMenu {
    enum Action {
        case moveNow
        case reset
        case pause(until: Date)
        case resume
        case settings
        case quit
    }

    @Observable
    final class Info {
        var status = ""
        var lastReminderHeading = ""
        var lastReminderExercise = ""
    }

    var onAction: (Action) -> Void = { _ in }

    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let info = Info()
    private let lastReminderItem = NSMenuItem()
    private let pauseItem = NSMenuItem(title: "Pause", action: nil, keyEquivalent: "")
    private lazy var resumeItem = actionItem("Resume", symbol: "play") { .resume }

    init() {
        item.button?.image = MoveLogo.menuBarImage()
        item.button?.setAccessibilityLabel("Move")

        let menu = NSMenu()
        menu.minimumWidth = 260
        let headerItem = NSMenuItem()
        headerItem.view = hostingView(StatusHeader(info: info))
        menu.addItem(headerItem)
        lastReminderItem.view = hostingView(LastReminderRow(info: info))
        lastReminderItem.isHidden = true
        menu.addItem(lastReminderItem)
        menu.addItem(.separator())
        menu.addItem(actionItem("Move now", symbol: "figure.run") { .moveNow })
        menu.addItem(actionItem("Reset timer", symbol: "arrow.counterclockwise") { .reset })

        let pauseMenu = NSMenu()
        pauseMenu.addItem(actionItem("For 30 minutes") { .pause(until: Date().addingTimeInterval(30 * 60)) })
        pauseMenu.addItem(actionItem("For 1 hour") { .pause(until: Date().addingTimeInterval(60 * 60)) })
        pauseMenu.addItem(actionItem("For 2 hours") { .pause(until: Date().addingTimeInterval(120 * 60)) })
        pauseMenu.addItem(actionItem("Until tomorrow") { .pause(until: .startOfTomorrow) })
        pauseMenu.addItem(actionItem("Until I resume") { .pause(until: .distantFuture) })
        pauseItem.image = NSImage(systemSymbolName: "pause", accessibilityDescription: nil)
        pauseItem.submenu = pauseMenu
        menu.addItem(pauseItem)

        resumeItem.isHidden = true
        menu.addItem(resumeItem)
        menu.addItem(.separator())
        menu.addItem(actionItem("Settings…", symbol: "gearshape", key: ",") { .settings })
        menu.addItem(actionItem("Quit Move", symbol: "power", key: "q") { .quit })
        item.menu = menu
    }

    func showStatus(_ status: String, isPaused: Bool) {
        info.status = status
        pauseItem.isHidden = isPaused
        resumeItem.isHidden = !isPaused
        item.button?.toolTip = "Move · \(status)"
    }

    func showLastReminder(heading: String, exercise: String) {
        info.lastReminderHeading = heading
        info.lastReminderExercise = exercise
        lastReminderItem.isHidden = false
    }

    private func actionItem(_ title: String, symbol: String? = nil, key: String = "", action: @escaping () -> Action) -> NSMenuItem {
        let item = ClosureMenuItem(title: title, keyEquivalent: key) { [unowned self] in onAction(action()) }
        item.image = symbol.flatMap { NSImage(systemSymbolName: $0, accessibilityDescription: nil) }
        return item
    }

    private func hostingView(_ view: some View) -> NSView {
        let hostingView = NSHostingView(rootView: view.frame(width: 260, alignment: .leading))
        hostingView.frame.size = hostingView.fittingSize
        return hostingView
    }
}

private final class ClosureMenuItem: NSMenuItem {
    private let handler: () -> Void

    init(title: String, keyEquivalent: String, handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(run), keyEquivalent: keyEquivalent)
        target = self
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    @objc private func run() {
        handler()
    }
}

private struct StatusHeader: View {
    let info: StatusMenu.Info

    var body: some View {
        HStack(spacing: 10) {
            MoveLogo().frame(width: 18, height: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text("Move").font(.caption).foregroundStyle(.secondary)
                Text(info.status).fontWeight(.semibold)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
    }
}

private struct LastReminderRow: View {
    let info: StatusMenu.Info

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "clock.arrow.circlepath")
                .foregroundStyle(.secondary)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text(info.lastReminderHeading).font(.caption).foregroundStyle(.secondary)
                Text(info.lastReminderExercise)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 2)
        .padding(.bottom, 6)
    }
}

extension Date {
    static var startOfTomorrow: Date {
        Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date()))!
    }
}
