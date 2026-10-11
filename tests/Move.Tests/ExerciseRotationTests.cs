using Move.Models;
using Move.Services;

namespace Move.Tests;

public class ExerciseRotationTests
{
    private static readonly List<Exercise> Exercises = Exercise.Defaults();

    [Fact]
    public void CyclesThroughExercisesInOrder()
    {
        var rotation = new ExerciseRotation(Exercises, shuffle: false, new RotationState(), new Random(1));

        List<string> seen = TakeNames(rotation, Exercises.Count * 2);

        Assert.Equal(Exercises.Select(e => e.Name).Concat(Exercises.Select(e => e.Name)), seen);
    }

    [Fact]
    public void ShuffleShowsEveryExerciseOncePerRoundWithoutBackToBackRepeats()
    {
        var rotation = new ExerciseRotation(Exercises, shuffle: true, new RotationState(), new Random(7));

        List<string> seen = TakeNames(rotation, Exercises.Count * 20);

        foreach (string[] round in seen.Chunk(Exercises.Count))
        {
            Assert.Equal(Exercises.Select(e => e.Name).Order(), round.Order());
        }

        Assert.All(seen.Zip(seen.Skip(1)), pair => Assert.NotEqual(pair.First, pair.Second));
    }

    [Fact]
    public void ContinuesFromSavedState()
    {
        var state = new RotationState { Order = [.. Enumerable.Range(0, Exercises.Count)], Position = 2 };

        var rotation = new ExerciseRotation(Exercises, shuffle: false, state, new Random(1));

        Assert.Equal(Exercises[2].Name, rotation.Current.Name);
    }

    [Fact]
    public void StartsOverWhenSavedStateDoesNotMatchTheExercises()
    {
        var state = new RotationState { Order = [0, 1], Position = 1 };

        var rotation = new ExerciseRotation(Exercises, shuffle: false, state, new Random(1));

        Assert.Equal(Exercises[0].Name, rotation.Current.Name);
        Assert.Equal(Exercises.Count, rotation.State.Order.Count);
    }

    [Fact]
    public void KeepsPositionWhenExercisesAreEditedButNotAddedOrRemoved()
    {
        var rotation = new ExerciseRotation(Exercises, shuffle: false, new RotationState(), new Random(1));
        rotation.Advance();
        rotation.Advance();

        List<Exercise> edited = Exercises.Select(e => e.Clone()).ToList();
        edited[2].Amount = 99;
        rotation.Update(edited, updatedShuffle: false);

        Assert.Equal(2, rotation.State.Position);
        Assert.Equal(99, rotation.Current.Amount);
    }

    private static List<string> TakeNames(ExerciseRotation rotation, int count)
    {
        var names = new List<string>();
        for (int i = 0; i < count; i++)
        {
            names.Add(rotation.Current.Name);
            rotation.Advance();
        }

        return names;
    }
}
