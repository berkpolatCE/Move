using Move.Models;

namespace Move.Services;

public sealed class ExerciseRotation
{
    private readonly Random random;
    private IReadOnlyList<Exercise> exercises;
    private bool shuffle;

    public ExerciseRotation(IReadOnlyList<Exercise> exercises, bool shuffle, RotationState state, Random random)
    {
        this.exercises = exercises;
        this.shuffle = shuffle;
        this.random = random;
        State = state;

        if (!IsValid(State))
        {
            StartNewRound(previous: null);
        }
    }

    public RotationState State { get; }
    public Exercise Current => exercises[State.Order[State.Position]];

    public void Advance()
    {
        int previous = State.Order[State.Position];
        State.Position++;

        if (State.Position >= State.Order.Count)
        {
            StartNewRound(previous);
        }
    }

    public void Update(IReadOnlyList<Exercise> updatedExercises, bool updatedShuffle)
    {
        bool orderChanged = updatedExercises.Count != exercises.Count || updatedShuffle != shuffle;
        exercises = updatedExercises;
        shuffle = updatedShuffle;

        if (orderChanged || !IsValid(State))
        {
            StartNewRound(previous: null);
        }
    }

    private bool IsValid(RotationState state) =>
        state.Order.Count == exercises.Count
        && state.Position >= 0
        && state.Position < state.Order.Count
        && state.Order.Order().SequenceEqual(Enumerable.Range(0, exercises.Count));

    private void StartNewRound(int? previous)
    {
        int[] order = Enumerable.Range(0, exercises.Count).ToArray();

        if (shuffle)
        {
            random.Shuffle(order);

            if (order.Length > 1 && order[0] == previous)
            {
                (order[0], order[^1]) = (order[^1], order[0]);
            }
        }

        State.Order = [.. order];
        State.Position = 0;
    }
}
