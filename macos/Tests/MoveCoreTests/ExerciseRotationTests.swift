import Testing
@testable import MoveCore

private let exercises = Exercise.defaults
private let names = exercises.map(\.name)

private struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

private func takeNames(_ rotation: ExerciseRotation, count: Int) -> [String] {
    (0..<count).map { _ in
        defer { rotation.advance() }
        return rotation.current.name
    }
}

@Test func cyclesThroughExercisesInOrder() {
    let rotation = ExerciseRotation(exercises: exercises, shuffle: false, state: RotationState())

    #expect(takeNames(rotation, count: exercises.count * 2) == names + names)
}

@Test func shuffleShowsEveryExerciseOncePerRoundWithoutBackToBackRepeats() {
    let rotation = ExerciseRotation(
        exercises: exercises, shuffle: true, state: RotationState(), random: SeededGenerator(state: 7))

    let seen = takeNames(rotation, count: exercises.count * 20)

    for start in stride(from: 0, to: seen.count, by: exercises.count) {
        #expect(seen[start..<start + exercises.count].sorted() == names.sorted())
    }

    #expect(zip(seen, seen.dropFirst()).allSatisfy { $0 != $1 })
    #expect(seen.prefix(exercises.count) != names[...])
}

@Test func continuesFromSavedState() {
    let state = RotationState(order: Array(exercises.indices), position: 2)

    let rotation = ExerciseRotation(exercises: exercises, shuffle: false, state: state)

    #expect(rotation.current.name == "Push-ups")
}

@Test func startsOverWhenSavedStateDoesNotMatchTheExercises() {
    let rotation = ExerciseRotation(exercises: exercises, shuffle: false, state: RotationState(order: [0, 1], position: 1))

    #expect(rotation.current.name == "Jumping jacks")
    #expect(rotation.state.order == [0, 1, 2, 3, 4, 5])
}

@Test func keepsPositionWhenExercisesAreEditedButNotAddedOrRemoved() {
    let rotation = ExerciseRotation(exercises: exercises, shuffle: false, state: RotationState())
    rotation.advance()
    rotation.advance()

    var edited = exercises
    edited[2].amount = 99
    rotation.update(exercises: edited, shuffle: false)

    #expect(rotation.state.position == 2)
    #expect(rotation.current.amount == 99)
}
