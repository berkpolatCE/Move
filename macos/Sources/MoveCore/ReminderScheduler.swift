import Foundation

public enum ReminderStatus: Sendable {
    case counting
    case due
    case paused
    case outsideActiveHours
}

public final class ReminderScheduler {
    private var settings: AppSettings

    public private(set) var elapsed: TimeInterval = 0
    public private(set) var target: TimeInterval = 0
    public private(set) var isSnoozed = false
    public private(set) var pausedUntil: Date?

    public init(settings: AppSettings) {
        self.settings = settings
        restart()
    }

    public var remaining: TimeInterval { max(target - elapsed, 0) }

    public func tick(now: Date, sinceLastTick: TimeInterval, idle: TimeInterval) -> ReminderStatus {
        if let until = pausedUntil {
            if now < until {
                return .paused
            }

            resume()
        }

        if !settings.isActive(at: now) {
            restart()
            return .outsideActiveHours
        }

        let wasAway = idle >= settings.idleReset || sinceLastTick >= settings.idleReset
        if settings.timerMode == .resetWhenIdle && wasAway {
            restart()
            return .counting
        }

        if sinceLastTick > 0 && sinceLastTick <= 30 {
            elapsed += sinceLastTick
        }

        return elapsed >= target ? .due : .counting
    }

    public func restart() {
        elapsed = 0
        target = settings.interval
        isSnoozed = false
    }

    public func snooze() {
        elapsed = 0
        target = settings.snooze
        isSnoozed = true
    }

    public func pause(until: Date) {
        pausedUntil = until
    }

    public func resume() {
        pausedUntil = nil
        restart()
    }

    public func apply(_ updated: AppSettings) {
        settings = updated
        target = isSnoozed ? settings.snooze : settings.interval
    }
}
