import Foundation
import Testing
@testable import MoveCore

private let noon = date(hour: 12)

func date(hour: Int, minute: Int = 0, day: Int = 12) -> Date {
    Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))!
}

private func settings(_ change: (inout AppSettings) -> Void) -> AppSettings {
    var settings = AppSettings()
    change(&settings)
    return settings
}

@discardableResult
private func run(_ scheduler: ReminderScheduler, minutes: Int, idle: TimeInterval = 0) -> ReminderStatus {
    var now = noon
    var status = ReminderStatus.counting

    for _ in 0..<(minutes * 60) {
        now += 1
        status = scheduler.tick(now: now, sinceLastTick: 1, idle: idle)
    }

    return status
}

@Test func becomesDueAfterTheInterval() {
    let scheduler = ReminderScheduler(settings: settings { $0.intervalMinutes = 60 })

    #expect(run(scheduler, minutes: 59) == .counting)
    #expect(run(scheduler, minutes: 1) == .due)
}

@Test func resetWhenIdleRestartsAfterSteppingAway() {
    let scheduler = ReminderScheduler(settings: settings { $0.timerMode = .resetWhenIdle; $0.idleResetMinutes = 10 })
    run(scheduler, minutes: 50)

    _ = scheduler.tick(now: noon, sinceLastTick: 1, idle: 10 * 60)

    #expect(scheduler.elapsed == 0)
}

@Test func resetWhenIdleKeepsCountingThroughShortBreaksInInput() {
    let scheduler = ReminderScheduler(settings: settings { $0.timerMode = .resetWhenIdle; $0.idleResetMinutes = 10 })

    run(scheduler, minutes: 30, idle: 9 * 60)

    #expect(scheduler.elapsed == 30 * 60)
}

@Test func fixedIntervalIgnoresIdleTime() {
    let scheduler = ReminderScheduler(settings: settings { $0.timerMode = .fixedInterval; $0.intervalMinutes = 60 })

    #expect(run(scheduler, minutes: 60, idle: 2 * 3600) == .due)
}

@Test func fixedIntervalDoesNotCountTimeAsleep() {
    let scheduler = ReminderScheduler(settings: settings { $0.timerMode = .fixedInterval })
    run(scheduler, minutes: 10)

    let status = scheduler.tick(now: noon + 3 * 3600, sinceLastTick: 3 * 3600, idle: 0)

    #expect(status == .counting)
    #expect(scheduler.elapsed == 10 * 60)
}

@Test func resetWhenIdleRestartsAfterLongSleep() {
    let scheduler = ReminderScheduler(settings: settings { $0.timerMode = .resetWhenIdle; $0.idleResetMinutes = 10 })
    run(scheduler, minutes: 30)

    _ = scheduler.tick(now: noon + 20 * 60, sinceLastTick: 20 * 60, idle: 0)

    #expect(scheduler.elapsed == 0)
}

@Test func snoozeWaitsForTheSnoozeLength() {
    let scheduler = ReminderScheduler(settings: settings { $0.intervalMinutes = 60; $0.snoozeMinutes = 10 })
    run(scheduler, minutes: 60)

    scheduler.snooze()

    #expect(scheduler.isSnoozed)
    #expect(run(scheduler, minutes: 9) == .counting)
    #expect(run(scheduler, minutes: 1) == .due)
}

@Test func restartClearsSnooze() {
    let scheduler = ReminderScheduler(settings: settings { $0.intervalMinutes = 60; $0.snoozeMinutes = 10 })
    scheduler.snooze()

    scheduler.restart()

    #expect(!scheduler.isSnoozed)
    #expect(scheduler.target == 60 * 60)
}

@Test func pauseHoldsUntilItEndsAndThenStartsFresh() {
    let scheduler = ReminderScheduler(settings: settings { $0.intervalMinutes = 60 })
    run(scheduler, minutes: 45)
    scheduler.pause(until: noon + 3600)

    #expect(scheduler.tick(now: noon + 59 * 60, sinceLastTick: 1, idle: 0) == .paused)
    #expect(scheduler.tick(now: noon + 3600, sinceLastTick: 1, idle: 0) == .counting)
    #expect(scheduler.pausedUntil == nil)
    #expect(scheduler.elapsed == 1)
}

@Test(arguments: [(8, false), (9, true), (17, true), (18, false)])
func activeHoursLimitWhenRemindersRun(hour: Int, expectedActive: Bool) {
    let scheduler = ReminderScheduler(settings: settings {
        $0.activeHoursEnabled = true
        $0.activeHoursStart = TimeOfDay(hour: 9, minute: 0)
        $0.activeHoursEnd = TimeOfDay(hour: 18, minute: 0)
    })

    let status = scheduler.tick(now: date(hour: hour, minute: 30), sinceLastTick: 1, idle: 0)

    #expect(status == (expectedActive ? .counting : .outsideActiveHours))
}

@Test(arguments: [(23, true), (3, true), (12, false)])
func activeHoursCanSpanMidnight(hour: Int, expectedActive: Bool) {
    let settings = settings {
        $0.activeHoursEnabled = true
        $0.activeHoursStart = TimeOfDay(hour: 22, minute: 0)
        $0.activeHoursEnd = TimeOfDay(hour: 6, minute: 0)
    }

    #expect(settings.isActive(at: date(hour: hour)) == expectedActive)
}

@Test func applyingSettingsUpdatesTheCurrentCountdown() {
    let scheduler = ReminderScheduler(settings: settings { $0.intervalMinutes = 60 })
    run(scheduler, minutes: 20)

    scheduler.apply(settings { $0.intervalMinutes = 30 })

    #expect(scheduler.remaining == 10 * 60)
}
