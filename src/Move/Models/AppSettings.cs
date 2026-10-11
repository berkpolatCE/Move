using System.Text.Json.Serialization;

namespace Move.Models;

public sealed class AppSettings
{
    public const int MinMinutes = 1;
    public const int MaxMinutes = 480;

    public TimerMode TimerMode { get; set; } = TimerMode.ResetWhenIdle;
    public int IntervalMinutes { get; set; } = 60;
    public int IdleResetMinutes { get; set; } = 10;
    public int SnoozeMinutes { get; set; } = 10;
    public bool ActiveHoursEnabled { get; set; }
    public TimeOnly ActiveHoursStart { get; set; } = new(9, 0);
    public TimeOnly ActiveHoursEnd { get; set; } = new(18, 0);
    public bool PlayChimeWithPopup { get; set; } = true;
    public bool ShuffleExercises { get; set; }
    public bool StartWithWindows { get; set; }
    public List<Exercise> Exercises { get; set; } = Exercise.Defaults();

    [JsonIgnore]
    public TimeSpan Interval => TimeSpan.FromMinutes(IntervalMinutes);

    [JsonIgnore]
    public TimeSpan IdleReset => TimeSpan.FromMinutes(IdleResetMinutes);

    [JsonIgnore]
    public TimeSpan Snooze => TimeSpan.FromMinutes(SnoozeMinutes);

    public bool IsActiveAt(DateTime now) =>
        !ActiveHoursEnabled
        || ActiveHoursStart == ActiveHoursEnd
        || TimeOnly.FromDateTime(now).IsBetween(ActiveHoursStart, ActiveHoursEnd);

    public AppSettings Normalized()
    {
        IntervalMinutes = Math.Clamp(IntervalMinutes, MinMinutes, MaxMinutes);
        IdleResetMinutes = Math.Clamp(IdleResetMinutes, MinMinutes, MaxMinutes);
        SnoozeMinutes = Math.Clamp(SnoozeMinutes, MinMinutes, MaxMinutes);

        Exercises = (Exercises ?? [])
            .Where(exercise => exercise is not null && !string.IsNullOrWhiteSpace(exercise.Name) && exercise.Amount > 0)
            .Select(exercise => new Exercise
            {
                Name = exercise.Name.Trim(),
                Amount = Math.Min(exercise.Amount, Exercise.MaxAmount),
                Unit = exercise.Unit,
                Tip = exercise.Tip?.Trim() ?? ""
            })
            .ToList();

        if (Exercises.Count == 0)
        {
            Exercises = Exercise.Defaults();
        }

        return this;
    }
}
