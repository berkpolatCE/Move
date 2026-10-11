using System.Text.Json.Serialization;

namespace Move.Models;

public sealed class Exercise
{
    public const int MaxAmount = 999;

    public string Name { get; set; } = "";
    public int Amount { get; set; }
    public ExerciseUnit Unit { get; set; }
    public string Tip { get; set; } = "";

    [JsonIgnore]
    public string AmountText => Unit == ExerciseUnit.Seconds
        ? Phrasing.Count(Amount, "second")
        : Phrasing.Count(Amount, "rep");

    public Exercise Clone() => new() { Name = Name, Amount = Amount, Unit = Unit, Tip = Tip };

    public static List<Exercise> Defaults() =>
    [
        new() { Name = "Jumping jacks", Amount = 30, Unit = ExerciseUnit.Reps, Tip = "Land softly and keep a steady rhythm." },
        new() { Name = "Squats", Amount = 15, Unit = ExerciseUnit.Reps, Tip = "Feet shoulder-width apart, chest up, push through your heels." },
        new() { Name = "Push-ups", Amount = 10, Unit = ExerciseUnit.Reps, Tip = "Keep your body in a straight line. Knees on the floor is fine." },
        new() { Name = "Wall sit", Amount = 45, Unit = ExerciseUnit.Seconds, Tip = "Back flat against the wall, knees bent to about 90 degrees." },
        new() { Name = "Calf raises", Amount = 20, Unit = ExerciseUnit.Reps, Tip = "Rise slowly onto your toes and lower back down with control." },
        new() { Name = "Stretch", Amount = 60, Unit = ExerciseUnit.Seconds, Tip = "Reach overhead, fold forward, then roll your neck and shoulders." },
    ];
}
