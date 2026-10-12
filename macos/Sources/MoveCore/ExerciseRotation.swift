public struct RotationState: Codable, Equatable, Sendable {
    public var order: [Int] = []
    public var position = 0

    public init(order: [Int] = [], position: Int = 0) {
        self.order = order
        self.position = position
    }

    private enum CodingKeys: String, CodingKey {
        case order = "Order"
        case position = "Position"
    }
}

public final class ExerciseRotation {
    private var exercises: [Exercise]
    private var shuffle: Bool
    private var random: any RandomNumberGenerator
    public private(set) var state: RotationState

    public init(
        exercises: [Exercise],
        shuffle: Bool,
        state: RotationState,
        random: any RandomNumberGenerator = SystemRandomNumberGenerator()
    ) {
        self.exercises = exercises
        self.shuffle = shuffle
        self.random = random
        self.state = state

        if !isValid(state) {
            startNewRound(previous: nil)
        }
    }

    public var current: Exercise { exercises[state.order[state.position]] }

    public func advance() {
        let previous = state.order[state.position]
        state.position += 1

        if state.position >= state.order.count {
            startNewRound(previous: previous)
        }
    }

    public func update(exercises updatedExercises: [Exercise], shuffle updatedShuffle: Bool) {
        let orderChanged = updatedExercises.count != exercises.count || updatedShuffle != shuffle
        exercises = updatedExercises
        shuffle = updatedShuffle

        if orderChanged || !isValid(state) {
            startNewRound(previous: nil)
        }
    }

    private func isValid(_ state: RotationState) -> Bool {
        state.order.count == exercises.count
            && state.position >= 0
            && state.position < state.order.count
            && state.order.sorted() == Array(exercises.indices)
    }

    private func startNewRound(previous: Int?) {
        var order = Array(exercises.indices)

        if shuffle {
            order.shuffle(using: &random)

            if order.count > 1 && order[0] == previous {
                order.swapAt(0, order.count - 1)
            }
        }

        state = RotationState(order: order, position: 0)
    }
}
