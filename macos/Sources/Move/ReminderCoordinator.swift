import AppKit
import MoveCore

@MainActor
final class ReminderCoordinator {
    private let store: SettingsStore
    private let scheduler: ReminderScheduler
    private let rotation: ExerciseRotation
    private let menu = StatusMenu()
    private var settings: AppSettings
    private var timer: Timer?
    private var lastTick = Date()
    private var reminder: ReminderPanel?
    private var banner: BannerPanel?
    private var settingsWindow: SettingsWindow?
    private var lastReminder: (exercise: Exercise, shownAt: Date)?

    init(store: SettingsStore) {
        self.store = store

        let isFirstRun = !store.settingsExist
        settings = store.loadSettings()
        if isFirstRun {
            store.saveSettings(settings)
        }

        if settings.openAtLogin {
            LoginItem.apply(true)
        }

        scheduler = ReminderScheduler(settings: settings)
        rotation = ExerciseRotation(
            exercises: settings.exercises, shuffle: settings.shuffleExercises, state: store.loadRotation())

        menu.onAction = { [unowned self] action in
            switch action {
            case .moveNow: showReminder(reason: "Here's your next exercise.")
            case .reset: runAndRefresh(scheduler.restart)
            case .pause(let until): pause(until: until)
            case .resume: runAndRefresh(scheduler.resume)
            case .settings: openSettings()
            case .quit: NSApp.terminate(nil)
            }
        }

        let timer = Timer(timeInterval: 1, repeats: true) { [unowned self] _ in
            MainActor.assumeIsolated { onTick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        updateMenu(.counting)

        if isFirstRun {
            openSettings(isFirstRun: true)
        }
    }

    func openSettings() {
        openSettings(isFirstRun: false)
    }

    private func onTick() {
        let now = Date()
        let sinceLastTick = now.timeIntervalSince(lastTick)
        lastTick = now

        var status = scheduler.tick(now: now, sinceLastTick: sinceLastTick, idle: UserActivity.idleTime)
        if status == .due && reminder == nil {
            status = handleDueReminder()
        }

        updateMenu(status)
    }

    private func handleDueReminder() -> ReminderStatus {
        switch UserActivity.presence() {
        case .away:
            return .due
        case .fullscreen:
            showBanner(rotation.current)
            Chime.playBells()
            moveToNextExercise()
            return .counting
        case .available:
            showReminder(reason: scheduler.isSnoozed ? "Snooze is over." : describeTimeSinceBreak())
            return .due
        }
    }

    private func describeTimeSinceBreak() -> String {
        let duration = Phrasing.duration(settings.interval)
        return settings.timerMode == .resetWhenIdle
            ? "You've been at your computer for \(duration)."
            : "It's been \(duration) since your last break."
    }

    private func showReminder(reason: String) {
        if let reminder {
            reminder.bringToFront()
            return
        }

        recordReminder(rotation.current)
        let panel = ReminderPanel(exercise: rotation.current, reason: reason, snoozeMinutes: settings.snoozeMinutes) {
            [unowned self] result in reminderClosed(result)
        }
        reminder = panel
        panel.show()

        if settings.playChimeWithPopup {
            Chime.playBells()
        }
    }

    private func reminderClosed(_ result: ReminderResult) {
        reminder = nil

        if result == .snoozed {
            scheduler.snooze()
            return
        }

        moveToNextExercise()
    }

    private func showBanner(_ exercise: Exercise) {
        recordReminder(exercise)
        banner?.close()
        banner = BannerPanel(exercise: exercise)
        banner?.show()
    }

    private func recordReminder(_ exercise: Exercise) {
        lastReminder = (exercise, Date())
    }

    private func moveToNextExercise() {
        rotation.advance()
        store.saveRotation(rotation.state)
        scheduler.restart()
    }

    private func pause(until: Date) {
        reminder?.close()
        scheduler.pause(until: until)
        updateMenu(.paused)
    }

    private func runAndRefresh(_ action: () -> Void) {
        action()
        updateMenu(.counting)
    }

    private func openSettings(isFirstRun: Bool) {
        if let settingsWindow {
            settingsWindow.show()
            return
        }

        let window = SettingsWindow(settings: settings, isFirstRun: isFirstRun) { [unowned self] updated in
            settingsWindow = nil
            if let updated {
                applySettings(updated)
            }
        }

        settingsWindow = window
        window.show()
    }

    private func applySettings(_ updated: AppSettings) {
        let loginChanged = updated.openAtLogin != settings.openAtLogin

        settings = updated
        scheduler.apply(settings)
        rotation.update(exercises: settings.exercises, shuffle: settings.shuffleExercises)
        store.saveRotation(rotation.state)

        if loginChanged {
            LoginItem.apply(settings.openAtLogin)
        }

        if !store.saveSettings(settings) {
            let alert = NSAlert()
            alert.messageText = "Move"
            alert.informativeText = "Your changes are active, but they couldn't be saved and will be lost when Move restarts."
            alert.alertStyle = .warning
            alert.runModal()
        }
    }

    private func updateMenu(_ status: ReminderStatus) {
        menu.showStatus(describeStatus(status), isPaused: status == .paused)

        if let (exercise, shownAt) = lastReminder {
            menu.showLastReminder(
                heading: "Last reminder · \(Phrasing.moment(shownAt, now: Date()))",
                exercise: "\(exercise.name) · \(exercise.amountText)")
        }
    }

    private func describeStatus(_ status: ReminderStatus) -> String {
        switch status {
        case .paused:
            return describePause(scheduler.pausedUntil)
        case .outsideActiveHours:
            return "Off until \(settings.activeHoursStart.text)"
        case .due:
            return "Time to move!"
        case .counting where scheduler.isSnoozed:
            return "Snoozed, \(rotation.current.name) in \(Phrasing.countdown(scheduler.remaining))"
        case .counting:
            return "\(rotation.current.name) in \(Phrasing.countdown(scheduler.remaining))"
        }
    }

    private func describePause(_ until: Date?) -> String {
        guard let until, until != .distantFuture else {
            return "Paused"
        }

        if until == .startOfTomorrow {
            return "Paused until tomorrow"
        }

        return "Paused until \(Phrasing.moment(until, now: Date()))"
    }
}
