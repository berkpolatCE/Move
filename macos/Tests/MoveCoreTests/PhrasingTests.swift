import Foundation
import Testing
@testable import MoveCore

@Test(arguments: [(1, "1 minute"), (45, "45 minutes"), (60, "an hour"), (90, "1 hour 30 minutes"), (120, "2 hours")])
func describesDurations(minutes: Int, expected: String) {
    #expect(Phrasing.duration(TimeInterval(minutes * 60)) == expected)
}

@Test(arguments: [(10, "10 minutes"), (60, "1 hour"), (90, "1 hour 30 minutes"), (120, "2 hours")])
func describesPickerLengths(minutes: Int, expected: String) {
    #expect(Phrasing.length(TimeInterval(minutes * 60)) == expected)
}

@Test(arguments: [
    (30, "under a minute"), (60, "1 min"), (61, "2 min"), (23 * 60, "23 min"), (60 * 60, "1 h"), (65 * 60, "1 h 5 min"),
])
func describesCountdowns(seconds: Int, expected: String) {
    #expect(Phrasing.countdown(TimeInterval(seconds)) == expected)
}

@Test func describesMomentsWithTheDayOnlyWhenItIsNotToday() {
    let now = date(hour: 18)
    let earlierToday = date(hour: 14, minute: 32)
    let lastNight = date(hour: 23, minute: 50, day: 11)

    #expect(Phrasing.moment(earlierToday, now: now) == earlierToday.formatted(date: .omitted, time: .shortened))
    #expect(Phrasing.moment(lastNight, now: now).hasPrefix(lastNight.formatted(.dateTime.weekday(.abbreviated)) + " "))
    #expect(Phrasing.moment(lastNight, now: now).hasSuffix(lastNight.formatted(date: .omitted, time: .shortened)))
}

@Test func describesExerciseAmounts() {
    #expect(Exercise(name: "", amount: 15, unit: .reps).amountText == "15 reps")
    #expect(Exercise(name: "", amount: 1, unit: .reps).amountText == "1 rep")
    #expect(Exercise(name: "", amount: 45, unit: .seconds).amountText == "45 seconds")
}

@Test(arguments: [(3, 3.0, 4.0), (1, 2.0, 3.0)])
func chimeProducesAValidWaveFile(bellCount: Int, minSeconds: Double, maxSeconds: Double) {
    let wave = Chime.wave(bellCount: bellCount)
    let riffSize = wave[4..<8].enumerated().reduce(0) { $0 | Int($1.element) << ($1.offset * 8) }

    #expect(String(decoding: wave[0..<4], as: UTF8.self) == "RIFF")
    #expect(String(decoding: wave[8..<16], as: UTF8.self) == "WAVEfmt ")
    #expect(riffSize == wave.count - 8)
    #expect((minSeconds...maxSeconds).contains(Double(wave.count) / 2 / Double(Chime.sampleRate)))
}
