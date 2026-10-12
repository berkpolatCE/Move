import Foundation

public enum TimerMode: String, Codable, Sendable {
    case resetWhenIdle = "ResetWhenIdle"
    case fixedInterval = "FixedInterval"
}

public struct TimeOfDay: Codable, Hashable, Comparable, Sendable {
    public var hour: Int
    public var minute: Int

    public init(hour: Int, minute: Int) {
        self.hour = hour
        self.minute = minute
    }

    public init(_ date: Date) {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
        self.init(hour: parts.hour ?? 0, minute: parts.minute ?? 0)
    }

    public var text: String {
        Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date())?
            .formatted(date: .omitted, time: .shortened) ?? ""
    }

    public func isBetween(_ start: TimeOfDay, _ end: TimeOfDay) -> Bool {
        start <= end ? start <= self && self < end : self >= start || self < end
    }

    public static func < (lhs: TimeOfDay, rhs: TimeOfDay) -> Bool {
        (lhs.hour, lhs.minute) < (rhs.hour, rhs.minute)
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let parts = try container.decode(String.self).split(separator: ":").compactMap { Int($0) }
        guard parts.count >= 2, (0..<24).contains(parts[0]), (0..<60).contains(parts[1]) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Expected a time like 09:00")
        }
        self.init(hour: parts[0], minute: parts[1])
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(String(format: "%02d:%02d:00", hour, minute))
    }
}

public struct AppSettings: Codable, Equatable, Sendable {
    public static let minMinutes = 1
    public static let maxMinutes = 480

    public var timerMode = TimerMode.resetWhenIdle
    public var intervalMinutes = 60
    public var idleResetMinutes = 10
    public var snoozeMinutes = 10
    public var activeHoursEnabled = false
    public var activeHoursStart = TimeOfDay(hour: 9, minute: 0)
    public var activeHoursEnd = TimeOfDay(hour: 18, minute: 0)
    public var playChimeWithPopup = true
    public var shuffleExercises = false
    public var openAtLogin = false
    public var exercises = Exercise.defaults

    public init() {}

    public var interval: TimeInterval { TimeInterval(intervalMinutes * 60) }
    public var idleReset: TimeInterval { TimeInterval(idleResetMinutes * 60) }
    public var snooze: TimeInterval { TimeInterval(snoozeMinutes * 60) }

    public func isActive(at date: Date) -> Bool {
        !activeHoursEnabled
            || activeHoursStart == activeHoursEnd
            || TimeOfDay(date).isBetween(activeHoursStart, activeHoursEnd)
    }

    public func normalized() -> AppSettings {
        var settings = self
        let range = Self.minMinutes...Self.maxMinutes
        settings.intervalMinutes = intervalMinutes.clamped(to: range)
        settings.idleResetMinutes = idleResetMinutes.clamped(to: range)
        settings.snoozeMinutes = snoozeMinutes.clamped(to: range)
        settings.exercises = exercises
            .filter { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.amount > 0 }
            .map {
                Exercise(
                    name: $0.name.trimmingCharacters(in: .whitespacesAndNewlines),
                    amount: min($0.amount, Exercise.maxAmount),
                    unit: $0.unit,
                    tip: $0.tip.trimmingCharacters(in: .whitespacesAndNewlines))
            }

        if settings.exercises.isEmpty {
            settings.exercises = Exercise.defaults
        }

        return settings
    }

    private enum CodingKeys: String, CodingKey {
        case timerMode = "TimerMode"
        case intervalMinutes = "IntervalMinutes"
        case idleResetMinutes = "IdleResetMinutes"
        case snoozeMinutes = "SnoozeMinutes"
        case activeHoursEnabled = "ActiveHoursEnabled"
        case activeHoursStart = "ActiveHoursStart"
        case activeHoursEnd = "ActiveHoursEnd"
        case playChimeWithPopup = "PlayChimeWithPopup"
        case shuffleExercises = "ShuffleExercises"
        case openAtLogin = "OpenAtLogin"
        case exercises = "Exercises"
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = AppSettings()
        timerMode = try container.decodeIfPresent(TimerMode.self, forKey: .timerMode) ?? defaults.timerMode
        intervalMinutes = try container.decodeIfPresent(Int.self, forKey: .intervalMinutes) ?? defaults.intervalMinutes
        idleResetMinutes = try container.decodeIfPresent(Int.self, forKey: .idleResetMinutes) ?? defaults.idleResetMinutes
        snoozeMinutes = try container.decodeIfPresent(Int.self, forKey: .snoozeMinutes) ?? defaults.snoozeMinutes
        activeHoursEnabled = try container.decodeIfPresent(Bool.self, forKey: .activeHoursEnabled) ?? defaults.activeHoursEnabled
        activeHoursStart = try container.decodeIfPresent(TimeOfDay.self, forKey: .activeHoursStart) ?? defaults.activeHoursStart
        activeHoursEnd = try container.decodeIfPresent(TimeOfDay.self, forKey: .activeHoursEnd) ?? defaults.activeHoursEnd
        playChimeWithPopup = try container.decodeIfPresent(Bool.self, forKey: .playChimeWithPopup) ?? defaults.playChimeWithPopup
        shuffleExercises = try container.decodeIfPresent(Bool.self, forKey: .shuffleExercises) ?? defaults.shuffleExercises
        openAtLogin = try container.decodeIfPresent(Bool.self, forKey: .openAtLogin) ?? defaults.openAtLogin
        exercises = try container.decodeIfPresent([Exercise].self, forKey: .exercises) ?? defaults.exercises
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
