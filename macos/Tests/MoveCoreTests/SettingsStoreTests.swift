import Foundation
import Testing
@testable import MoveCore

struct SettingsStoreTests {
    let directory = FileManager.default.temporaryDirectory.appending(path: "Move.Tests/\(UUID().uuidString)")

    @Test func roundTripsSettings() throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = SettingsStore(directory: directory)
        var settings = AppSettings()
        settings.timerMode = .fixedInterval
        settings.intervalMinutes = 45
        settings.activeHoursEnabled = true
        settings.activeHoursStart = TimeOfDay(hour: 8, minute: 30)
        settings.exercises = [Exercise(name: "Lunges", amount: 12)]

        #expect(store.saveSettings(settings))
        let loaded = store.loadSettings()

        #expect(loaded.timerMode == .fixedInterval)
        #expect(loaded.intervalMinutes == 45)
        #expect(loaded.activeHoursStart == TimeOfDay(hour: 8, minute: 30))
        #expect(loaded.exercises.map(\.name) == ["Lunges"])
    }

    @Test func readsSettingsWrittenByTheWindowsApp() throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let json = """
            {
              "TimerMode": "FixedInterval",
              "IntervalMinutes": 25,
              "ActiveHoursStart": "07:30:00",
              "StartWithWindows": true,
              "Exercises": [{ "Name": "Plank", "Amount": 40, "Unit": "Seconds", "Tip": "" }]
            }
            """
        try Data(json.utf8).write(to: directory.appending(path: "settings.json"))

        let loaded = SettingsStore(directory: directory).loadSettings()

        #expect(loaded.timerMode == .fixedInterval)
        #expect(loaded.intervalMinutes == 25)
        #expect(loaded.snoozeMinutes == 10)
        #expect(loaded.activeHoursStart == TimeOfDay(hour: 7, minute: 30))
        #expect(loaded.exercises == [Exercise(name: "Plank", amount: 40, unit: .seconds)])
    }

    @Test func fallsBackToDefaultsWhenTheFileIsCorrupt() throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("{ not json".utf8).write(to: directory.appending(path: "settings.json"))

        let loaded = SettingsStore(directory: directory).loadSettings()

        #expect(loaded.intervalMinutes == 60)
        #expect(loaded.exercises.count == 6)
    }

    @Test func normalizingClampsValuesAndRestoresExercises() {
        var settings = AppSettings()
        settings.intervalMinutes = 0
        settings.snoozeMinutes = 10_000
        settings.exercises = [Exercise(name: "  ", amount: 5)]

        let normalized = settings.normalized()

        #expect(normalized.intervalMinutes == 1)
        #expect(normalized.snoozeMinutes == 480)
        #expect(normalized.exercises.count == 6)
    }
}
