import Foundation

public enum Phrasing {
    public static func count(_ amount: Int, _ unit: String) -> String {
        amount == 1 ? "1 \(unit)" : "\(amount) \(unit)s"
    }

    public static func duration(_ duration: TimeInterval) -> String {
        duration == 3600 ? "an hour" : length(duration)
    }

    public static func length(_ duration: TimeInterval) -> String {
        let totalMinutes = Int((duration / 60).rounded(.toNearestOrEven))
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours == 0 {
            return count(minutes, "minute")
        }

        return minutes == 0 ? count(hours, "hour") : "\(count(hours, "hour")) \(count(minutes, "minute"))"
    }

    public static func moment(_ when: Date, now: Date) -> String {
        let time = when.formatted(date: .omitted, time: .shortened)
        return Calendar.current.isDate(when, inSameDayAs: now)
            ? time
            : "\(when.formatted(.dateTime.weekday(.abbreviated))) \(time)"
    }

    public static func countdown(_ remaining: TimeInterval) -> String {
        if remaining < 60 {
            return "under a minute"
        }

        let totalMinutes = Int((remaining / 60).rounded(.up))
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        switch (hours, minutes) {
        case (0, _): return "\(minutes) min"
        case (_, 0): return "\(hours) h"
        default: return "\(hours) h \(minutes) min"
        }
    }
}
